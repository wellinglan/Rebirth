from __future__ import annotations

import copy
import threading
import uuid
from pathlib import Path
from typing import Any

from fastapi.testclient import TestClient
from sqlalchemy import inspect, select
from alembic import command
from alembic.config import Config

from app.ai.canonical import input_hash
from app.ai.providers import FakeAiProvider
from app.ai.schemas import AiWeeklyPayload
from app.ai.service import AiGenerationService
from app.models import AiGenerationRequest
from tests.test_ai_gateway import fixture_payload, request_body


class MutableClock:
    def __init__(self, value: int = 2_000_000_000_000) -> None:
        self.value = value

    def __call__(self) -> int:
        return self.value


def _service(
    client: TestClient,
    *,
    provider: FakeAiProvider | None = None,
    clock: MutableClock | None = None,
) -> tuple[FakeAiProvider, MutableClock]:
    active_provider = provider or FakeAiProvider()
    active_clock = clock or MutableClock()
    client.app.state.ai_generation_service = AiGenerationService(
        client.app.state.settings,
        active_provider,
        active_clock,
    )
    return active_provider, active_clock


def _login(client: TestClient, key: str) -> dict[str, str]:
    response = client.post("/auth/dev-login", json={"dev_user_key": key})
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def _ledger_row(client: TestClient) -> AiGenerationRequest:
    with client.app.state.database.session_factory() as session:
        row = session.scalar(select(AiGenerationRequest))
        assert row is not None
        session.expunge(row)
        return row


def _insert_processing(
    client: TestClient,
    auth_headers: dict[str, str],
    *,
    clock: MutableClock,
    lease_expires_at: int,
) -> None:
    user = client.get("/ai/capabilities", headers=auth_headers)
    assert user.status_code == 200
    token = auth_headers["Authorization"].split(" ", 1)[1]
    from app.security import jwt

    user_id = jwt.decode(
        token,
        client.app.state.settings.jwt_secret,
        algorithms=["HS256"],
    )["sub"]
    body = request_body()
    with client.app.state.database.session_factory() as session:
        session.add(
            AiGenerationRequest(
                id=str(uuid.uuid4()),
                user_id=user_id,
                request_id=body["request_id"],
                input_hash=body["input_hash"],
                report_type="weekly_report",
                prompt_version="weekly-report-v1",
                status="processing",
                provider=None,
                model=None,
                output_schema_version=None,
                report_content=None,
                structured_output_json=None,
                error_code=None,
                created_at=clock.value,
                updated_at=clock.value,
                lease_expires_at=lease_expires_at,
                result_expires_at=None,
                dedupe_expires_at=clock.value + 30 * 24 * 60 * 60 * 1000,
                result_purged_at=None,
            )
        )
        session.commit()


def test_first_claim_and_completed_duplicate_replay(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    provider, _ = _service(client)
    first = client.post(
        "/ai/reports/weekly/generate", headers=auth_headers, json=request_body()
    )
    second = client.post(
        "/ai/reports/weekly/generate", headers=auth_headers, json=request_body()
    )
    assert first.status_code == second.status_code == 200
    assert first.json() == second.json()
    assert provider.calls == 1
    assert _ledger_row(client).status == "completed"


def test_duplicate_different_identity_returns_conflict(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    provider, _ = _service(client)
    assert client.post(
        "/ai/reports/weekly/generate", headers=auth_headers, json=request_body()
    ).status_code == 200
    for field, value in (
        ("input", "different"),
        ("prompt", "weekly-report-v2"),
        ("report", "daily_insight"),
    ):
        payload = copy.deepcopy(fixture_payload())
        if field == "input":
            payload["data"]["today_metrics"][0]["research_minutes"] = 99
        elif field == "prompt":
            payload["prompt_version"] = value
        else:
            payload["report_type"] = value
        body = request_body(payload)
        body["input_hash"] = input_hash(AiWeeklyPayload.model_validate(payload))
        response = client.post(
            "/ai/reports/weekly/generate", headers=auth_headers, json=body
        )
        assert response.status_code == 409
        assert response.json()["detail"]["code"] == "idempotency_conflict"
    assert provider.calls == 1


def test_same_request_id_is_isolated_by_user(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    provider, _ = _service(client)
    other_headers = _login(client, "other-ai-user")
    assert client.post(
        "/ai/reports/weekly/generate", headers=auth_headers, json=request_body()
    ).status_code == 200
    assert client.post(
        "/ai/reports/weekly/generate", headers=other_headers, json=request_body()
    ).status_code == 200
    assert provider.calls == 2
    hidden = client.get(
        f"/ai/requests/{request_body()['request_id']}", headers=_login(client, "third-user")
    )
    assert hidden.status_code == 404
    assert "user_id" not in hidden.text


def test_active_processing_returns_202_without_provider_call(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    provider, clock = _service(client)
    _insert_processing(
        client,
        auth_headers,
        clock=clock,
        lease_expires_at=clock.value + 60_000,
    )
    response = client.post(
        "/ai/reports/weekly/generate", headers=auth_headers, json=request_body()
    )
    assert response.status_code == 202
    assert response.json()["status"] == "processing"
    assert provider.calls == 0


def test_stale_processing_becomes_outcome_unknown(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    provider, clock = _service(client)
    _insert_processing(
        client,
        auth_headers,
        clock=clock,
        lease_expires_at=clock.value - 1,
    )
    response = client.post(
        "/ai/reports/weekly/generate", headers=auth_headers, json=request_body()
    )
    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "outcome_unknown"
    status = client.get(
        f"/ai/requests/{request_body()['request_id']}", headers=auth_headers
    )
    assert status.status_code == 200
    assert status.json()["status"] == "outcome_unknown"
    assert "cost" in status.json()["outcome_note"]
    assert provider.calls == 0


def test_failed_duplicate_replays_controlled_error(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    provider, _ = _service(client, provider=FakeAiProvider("timeout"))
    first = client.post(
        "/ai/reports/weekly/generate", headers=auth_headers, json=request_body()
    )
    second = client.post(
        "/ai/reports/weekly/generate", headers=auth_headers, json=request_body()
    )
    assert first.status_code == second.status_code == 504
    assert second.json()["detail"]["code"] == "provider_timeout"
    assert provider.calls == 1
    row = _ledger_row(client)
    assert row.error_code == "provider_timeout"
    assert "Traceback" not in (row.error_code or "")


def test_result_ttl_purges_output_but_keeps_tombstone(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    provider, clock = _service(client)
    assert client.post(
        "/ai/reports/weekly/generate", headers=auth_headers, json=request_body()
    ).status_code == 200
    clock.value += 24 * 60 * 60 * 1000 + 1
    status = client.get(
        f"/ai/requests/{request_body()['request_id']}", headers=auth_headers
    )
    assert status.status_code == 200
    assert status.json()["status"] == "result_expired"
    assert status.json()["report_content"] is None
    replay = client.post(
        "/ai/reports/weekly/generate", headers=auth_headers, json=request_body()
    )
    assert replay.status_code == 410
    assert replay.json()["detail"]["code"] == "result_expired"
    assert provider.calls == 1
    row = _ledger_row(client)
    assert row.report_content is None
    assert row.input_hash == request_body()["input_hash"]


def test_dedupe_ttl_lazy_cleanup_removes_row(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    provider, clock = _service(client)
    assert client.post(
        "/ai/reports/weekly/generate", headers=auth_headers, json=request_body()
    ).status_code == 200
    clock.value += 30 * 24 * 60 * 60 * 1000 + 1
    assert client.get(
        f"/ai/requests/{request_body()['request_id']}", headers=auth_headers
    ).status_code == 404
    assert client.post(
        "/ai/reports/weekly/generate", headers=auth_headers, json=request_body()
    ).status_code == 200
    assert provider.calls == 2


def test_ledger_schema_contains_no_input_payload_columns(client: TestClient) -> None:
    columns = {
        item["name"]
        for item in inspect(client.app.state.database.engine).get_columns(
            "ai_generation_requests"
        )
    }
    assert {
        "payload",
        "payload_json",
        "canonical_json",
        "sources",
        "sources_json",
        "journal",
        "provider_response",
        "api_key",
    }.isdisjoint(columns)


class BlockingFakeProvider(FakeAiProvider):
    def __init__(self) -> None:
        super().__init__()
        self.started = threading.Event()
        self.release = threading.Event()

    async def generate(self, **kwargs: Any):
        import asyncio

        self.started.set()
        await asyncio.to_thread(self.release.wait, 5)
        return await super().generate(**kwargs)


def test_concurrent_duplicate_calls_provider_once(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    provider = BlockingFakeProvider()
    _service(client, provider=provider)
    results: list[int] = []

    def send() -> None:
        response = client.post(
            "/ai/reports/weekly/generate",
            headers=auth_headers,
            json=request_body(),
        )
        results.append(response.status_code)

    first = threading.Thread(target=send)
    first.start()
    assert provider.started.wait(5)
    second = threading.Thread(target=send)
    second.start()
    second.join(5)
    provider.release.set()
    first.join(5)
    assert sorted(results) == [200, 202]
    assert provider.calls == 1


def test_alembic_upgrade_adds_ledger_without_losing_existing_user(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    database_path = tmp_path / "migration.sqlite"
    monkeypatch.setenv(
        "REBIRTH_DATABASE_URL", f"sqlite:///{database_path.as_posix()}"
    )
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", f"sqlite:///{database_path.as_posix()}")
    command.upgrade(config, "20260716_0001")
    from sqlalchemy import create_engine, text

    engine = create_engine(f"sqlite:///{database_path.as_posix()}")
    with engine.begin() as connection:
        connection.execute(
            text(
                "INSERT INTO cloud_users "
                "(id, display_name, created_at, updated_at, deleted_at) "
                "VALUES ('existing-user', 'Existing', 1, 1, NULL)"
            )
        )
    command.upgrade(config, "head")
    with engine.connect() as connection:
        assert connection.scalar(
            text("SELECT display_name FROM cloud_users WHERE id='existing-user'")
        ) == "Existing"
    assert "ai_generation_requests" in inspect(engine).get_table_names()
    engine.dispose()
