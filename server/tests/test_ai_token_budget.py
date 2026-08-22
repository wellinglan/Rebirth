from __future__ import annotations

import uuid
from dataclasses import replace

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.ai.errors import UsageLimitReachedError
from app.ai.usage import AiUsageGuard
from app.models import AiUsageRecord


_DAY_MS = 24 * 60 * 60 * 1000
_DAY_START = 1_785_542_400_000
_NOW = _DAY_START + 3_600_000


def _user(client: TestClient, key: str) -> tuple[dict[str, str], str]:
    response = client.post("/auth/dev-login", json={"dev_user_key": key})
    assert response.status_code == 200
    body = response.json()
    return (
        {"Authorization": f"Bearer {body['access_token']}"},
        body["user"]["id"],
    )


def _guard(client: TestClient, **changes: int) -> AiUsageGuard:
    return AiUsageGuard(replace(client.app.state.settings, **changes))


def _reserve(
    guard: AiUsageGuard,
    session: object,
    *,
    user_id: str,
    request_type: str = "coach_chat",
    tokens: int = 1_000,
    now: int = _NOW,
):
    return guard.reserve(
        session,
        user_id=user_id,
        request_id=str(uuid.uuid4()),
        provider="fake",
        model="deterministic-test-provider",
        request_type=request_type,
        now=now,
        estimated_tokens=tokens,
    )


def test_usage_v2_requires_jwt_and_exposes_only_personal_token_budgets(
    client: TestClient,
) -> None:
    assert client.get("/ai/usage/me/v2").status_code == 401
    headers, _ = _user(client, "token-budget-shape")

    response = client.get(
        "/ai/usage/me/v2?user_id=forbidden-other-user",
        headers=headers,
    )

    assert response.status_code == 200
    body = response.json()
    assert body["reset_timezone"] == "UTC"
    assert body["chat"] == {
        "unit": "tokens",
        "status": "disabled",
        "availability": "disabled",
        "limit": 50_000,
        "used": 0,
        "reserved": 0,
        "remaining": 50_000,
        "resets_at": body["resets_at"],
    }
    assert body["reports"]["unit"] == "tokens"
    assert not {
        "user_id",
        "global_limit",
        "api_key",
        "secret",
        "prompt",
        "journal",
        "health",
    }.intersection(body)


def test_reservation_is_visible_then_actual_provider_tokens_are_settled(
    client: TestClient,
) -> None:
    _, user_id = _user(client, "token-budget-settlement")
    guard = _guard(client)
    with client.app.state.database.session_factory() as session:
        reservation = _reserve(
            guard,
            session,
            user_id=user_id,
            tokens=4_000,
        )
        pending = guard.snapshot_v2(
            session,
            user_id=user_id,
            provider_enabled=True,
            now=_NOW,
        )
        assert pending.chat.used == 0
        assert pending.chat.reserved == 4_000
        assert pending.chat.remaining == 46_000

        guard.mark_completed(
            session,
            reservation,
            model="provider-model",
            input_tokens=700,
            output_tokens=300,
            total_tokens=1_000,
            now=_NOW + 1,
        )
        settled = guard.snapshot_v2(
            session,
            user_id=user_id,
            provider_enabled=True,
            now=_NOW + 1,
        )
        assert settled.chat.used == 1_000
        assert settled.chat.reserved == 0
        assert settled.chat.remaining == 49_000
        row = session.scalar(
            select(AiUsageRecord).where(
                AiUsageRecord.id == reservation.record_id
            )
        )
        assert row is not None
        assert row.accounting_source == "provider_total"
        assert row.charged_tokens == 1_000


def test_exact_50k_chat_boundary_rejects_the_next_reservation(
    client: TestClient,
) -> None:
    _, user_id = _user(client, "token-budget-boundary")
    guard = _guard(
        client,
        ai_chat_daily_token_limit=50_000,
        ai_max_request_tokens=50_000,
    )
    with client.app.state.database.session_factory() as session:
        _reserve(guard, session, user_id=user_id, tokens=50_000)
        snapshot = guard.snapshot_v2(
            session,
            user_id=user_id,
            provider_enabled=True,
            now=_NOW,
        )
        assert snapshot.chat.remaining == 0
        assert snapshot.chat.status == "limit_reached"
        with pytest.raises(UsageLimitReachedError):
            _reserve(guard, session, user_id=user_id, tokens=1)


def test_chat_report_and_account_budgets_are_isolated(
    client: TestClient,
) -> None:
    _, user_a = _user(client, "token-budget-account-a")
    _, user_b = _user(client, "token-budget-account-b")
    guard = _guard(client)
    with client.app.state.database.session_factory() as session:
        chat = _reserve(guard, session, user_id=user_a, tokens=1_200)
        report = _reserve(
            guard,
            session,
            user_id=user_a,
            request_type="weekly_report",
            tokens=2_400,
        )
        guard.mark_failed(session, chat, now=_NOW + 1)
        guard.mark_failed(session, report, now=_NOW + 1)

        account_a = guard.snapshot_v2(
            session,
            user_id=user_a,
            provider_enabled=True,
            now=_NOW + 1,
        )
        account_b = guard.snapshot_v2(
            session,
            user_id=user_b,
            provider_enabled=True,
            now=_NOW + 1,
        )
        assert account_a.chat.used == 1_200
        assert account_a.reports.used == 2_400
        assert account_b.chat.used == 0
        assert account_b.reports.used == 0


def test_known_pre_provider_release_charges_nothing(client: TestClient) -> None:
    _, user_id = _user(client, "token-budget-release")
    guard = _guard(client)
    with client.app.state.database.session_factory() as session:
        reservation = _reserve(
            guard,
            session,
            user_id=user_id,
            tokens=3_000,
        )
        guard.release(session, reservation, now=_NOW + 1)
        snapshot = guard.snapshot_v2(
            session,
            user_id=user_id,
            provider_enabled=True,
            now=_NOW + 1,
        )
        assert snapshot.chat.used == 0
        assert snapshot.chat.reserved == 0
        row = session.get(AiUsageRecord, reservation.record_id)
        assert row is not None
        assert row.accounting_source == "released_before_provider"


def test_unknown_outcome_holds_then_lease_expiry_charges_fallback(
    client: TestClient,
) -> None:
    _, user_id = _user(client, "token-budget-timeout")
    guard = _guard(client, ai_processing_lease_minutes=1)
    with client.app.state.database.session_factory() as session:
        reservation = _reserve(
            guard,
            session,
            user_id=user_id,
            tokens=2_500,
        )
        guard.hold_unknown(session, reservation, now=_NOW + 1)
        held = guard.snapshot_v2(
            session,
            user_id=user_id,
            provider_enabled=True,
            now=_NOW + 30_000,
        )
        assert held.chat.used == 0
        assert held.chat.reserved == 2_500

        expired = guard.snapshot_v2(
            session,
            user_id=user_id,
            provider_enabled=True,
            now=_NOW + 60_001,
        )
        assert expired.chat.used == 2_500
        assert expired.chat.reserved == 0
        row = session.get(AiUsageRecord, reservation.record_id)
        assert row is not None
        assert row.status == "expired"
        assert row.accounting_source == "lease_expired_fallback"


def test_token_budget_resets_at_utc_day_boundary(client: TestClient) -> None:
    _, user_id = _user(client, "token-budget-utc-reset")
    guard = _guard(client)
    with client.app.state.database.session_factory() as session:
        reservation = _reserve(
            guard,
            session,
            user_id=user_id,
            tokens=900,
            now=_DAY_START + _DAY_MS - 2,
        )
        guard.mark_failed(
            session,
            reservation,
            now=_DAY_START + _DAY_MS - 1,
        )
        before = guard.snapshot_v2(
            session,
            user_id=user_id,
            provider_enabled=True,
            now=_DAY_START + _DAY_MS - 1,
        )
        after = guard.snapshot_v2(
            session,
            user_id=user_id,
            provider_enabled=True,
            now=_DAY_START + _DAY_MS,
        )
        assert before.chat.used == 900
        assert before.resets_at == _DAY_START + _DAY_MS
        assert after.chat.used == 0
        assert after.chat.remaining == 50_000
        assert after.resets_at == _DAY_START + 2 * _DAY_MS
