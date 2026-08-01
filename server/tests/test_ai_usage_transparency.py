from __future__ import annotations

import uuid
from dataclasses import replace

import pytest
from fastapi.testclient import TestClient

from app.ai.providers import FakeAiProvider
from app.ai.service import AiGenerationService
from tests.test_ai_gateway import request_body


_DAY_MS = 24 * 60 * 60 * 1000
_DAY_START = 1_785_542_400_000


class _Clock:
    def __init__(self, now: int = _DAY_START + 3_600_000) -> None:
        self.now = now

    def __call__(self) -> int:
        return self.now


def _headers(client: TestClient, key: str) -> dict[str, str]:
    response = client.post("/auth/dev-login", json={"dev_user_key": key})
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def _set_service(
    client: TestClient,
    *,
    scenario: str = "success",
    user_limit: int = 10,
    global_limit: int = 100,
    concurrent_limit: int = 5,
    clock: _Clock | None = None,
) -> FakeAiProvider:
    provider = FakeAiProvider(scenario)
    settings = replace(
        client.app.state.settings,
        ai_daily_user_limit=user_limit,
        ai_daily_global_limit=global_limit,
        ai_max_concurrent_requests=concurrent_limit,
    )
    client.app.state.ai_generation_service = AiGenerationService(
        settings,
        provider,
        clock or _Clock(),
    )
    return provider


def _new_body() -> dict[str, object]:
    body = request_body()
    body["request_id"] = str(uuid.uuid4())
    return body


def test_usage_requires_jwt_and_returns_only_personal_safe_fields(
    client: TestClient,
) -> None:
    assert client.get("/ai/usage/me").status_code == 401
    _set_service(client)
    headers = _headers(client, "usage-safe-fields")
    response = client.get("/ai/usage/me", headers=headers)
    assert response.status_code == 200
    assert response.json() == {
        "enabled": True,
        "status": "available",
        "daily_limit": 10,
        "used": 0,
        "remaining": 10,
        "resets_at": _DAY_START + _DAY_MS,
        "reset_timezone": "UTC",
    }
    forbidden = {
        "global_limit",
        "global_used",
        "user_id",
        "api_key",
        "secret",
        "prompt",
        "journal",
        "health",
    }
    assert not forbidden.intersection(response.json())


def test_usage_is_isolated_and_ignores_submitted_user_id(
    client: TestClient,
) -> None:
    _set_service(client)
    user_a = _headers(client, "usage-isolation-a")
    user_b = _headers(client, "usage-isolation-b")
    assert client.post(
        "/ai/reports/weekly/generate",
        headers=user_a,
        json=_new_body(),
    ).status_code == 200
    assert client.get("/ai/usage/me", headers=user_a).json()["used"] == 1
    response = client.get(
        "/ai/usage/me?user_id=usage-isolation-a",
        headers=user_b,
    )
    assert response.status_code == 200
    assert response.json()["used"] == 0


def test_success_and_request_id_replay_count_once(client: TestClient) -> None:
    provider = _set_service(client)
    headers = _headers(client, "usage-idempotency")
    body = _new_body()
    assert client.post(
        "/ai/reports/weekly/generate", headers=headers, json=body
    ).status_code == 200
    assert client.post(
        "/ai/reports/weekly/generate", headers=headers, json=body
    ).status_code == 200
    usage = client.get("/ai/usage/me", headers=headers).json()
    assert usage["used"] == 1
    assert usage["remaining"] == 9
    assert provider.calls == 1


@pytest.mark.parametrize(
    ("scenario", "expected_status"),
    [("unavailable", 503), ("timeout", 504)],
)
def test_provider_failure_and_timeout_count_as_usage(
    client: TestClient,
    scenario: str,
    expected_status: int,
) -> None:
    _set_service(client, scenario=scenario)
    headers = _headers(client, f"usage-{scenario}")
    response = client.post(
        "/ai/reports/weekly/generate",
        headers=headers,
        json=_new_body(),
    )
    assert response.status_code == expected_status
    assert client.get("/ai/usage/me", headers=headers).json()["used"] == 1


def test_local_limit_rejection_does_not_add_usage(client: TestClient) -> None:
    provider = _set_service(client, user_limit=1)
    headers = _headers(client, "usage-local-limit")
    assert client.post(
        "/ai/reports/weekly/generate",
        headers=headers,
        json=_new_body(),
    ).status_code == 200
    rejected = client.post(
        "/ai/reports/weekly/generate",
        headers=headers,
        json=_new_body(),
    )
    assert rejected.status_code == 429
    usage = client.get("/ai/usage/me", headers=headers).json()
    assert usage["status"] == "limit_reached"
    assert usage["used"] == 1
    assert usage["remaining"] == 0
    assert provider.calls == 1


def test_usage_resets_on_the_utc_day_boundary(client: TestClient) -> None:
    clock = _Clock(_DAY_START + _DAY_MS - 1_000)
    _set_service(client, clock=clock)
    headers = _headers(client, "usage-utc-reset")
    assert client.post(
        "/ai/reports/weekly/generate",
        headers=headers,
        json=_new_body(),
    ).status_code == 200
    before = client.get("/ai/usage/me", headers=headers).json()
    assert before["used"] == 1
    assert before["resets_at"] == _DAY_START + _DAY_MS

    clock.now = _DAY_START + _DAY_MS
    after = client.get("/ai/usage/me", headers=headers).json()
    assert after["used"] == 0
    assert after["remaining"] == 10
    assert after["resets_at"] == _DAY_START + 2 * _DAY_MS


def test_disabled_provider_reports_disabled_without_changing_usage(
    client: TestClient,
    auth_headers: dict[str, str],
) -> None:
    response = client.get("/ai/usage/me", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["enabled"] is False
    assert response.json()["status"] == "disabled"
    assert response.json()["used"] == 0
