from __future__ import annotations

import asyncio
import json
import logging
import time
import uuid
from dataclasses import replace
from typing import Any

import httpx
import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, inspect, select

from app.ai.prompts import get_prompt
from app.ai.providers import DeepSeekProvider, FakeAiProvider, ProviderPromptPayload
from app.ai.service import AiGenerationService
from app.config import load_settings
from app.models import AiGenerationRequest, AiUsageRecord, CloudUser
from tests.test_ai_gateway import request_body


def _weekly_output() -> dict[str, Any]:
    return {
        "title": "Weekly reflection",
        "summary": "A concise summary.",
        "observations": [],
        "suggestions": [],
        "data_limitations": [],
    }


class _DeepSeekResponse:
    def __init__(self, status_code: int = 200) -> None:
        self.status_code = status_code

    def json(self) -> dict[str, Any]:
        return {
            "model": "deepseek-chat",
            "choices": [
                {
                    "finish_reason": "stop",
                    "message": {"content": json.dumps(_weekly_output())},
                }
            ],
            "usage": {
                "prompt_tokens": 31,
                "completion_tokens": 17,
                "total_tokens": 48,
            },
        }


class _DeepSeekClient:
    def __init__(
        self,
        *,
        status_code: int = 200,
        error: Exception | None = None,
    ) -> None:
        self.status_code = status_code
        self.error = error
        self.calls = 0
        self.kwargs: dict[str, Any] | None = None

    async def post(self, path: str, **kwargs: Any) -> _DeepSeekResponse:
        self.calls += 1
        self.kwargs = {"path": path, **kwargs}
        if self.error is not None:
            raise self.error
        return _DeepSeekResponse(self.status_code)


def _deepseek_provider(
    client: _DeepSeekClient,
    *,
    api_key: str = "deepseek-test-secret",
) -> DeepSeekProvider:
    settings = load_settings(
        environment="development",
        jwt_secret="test-secret",
        ai_provider="deepseek",
        deepseek_api_key=api_key,
        ai_model="deepseek-chat",
    )
    return DeepSeekProvider(settings, client=client)


def _generate(provider: DeepSeekProvider):
    prompt = get_prompt("weekly_report", "weekly-report-v1")
    assert prompt is not None
    return asyncio.run(
        provider.generate(
            payload=ProviderPromptPayload(
                report_type="weekly_report",
                prompt_version="weekly-report-v1",
                period={
                    "start_date": "2026-07-10",
                    "end_date": "2026-07-16",
                },
                scopes=["today_metrics"],
                data={"today_metrics": []},
            ),
            prompt=prompt,
            safety_identifier="not-forwarded",
        )
    )


def _set_fake_service(
    client: TestClient,
    *,
    user_limit: int = 10,
    global_limit: int = 100,
    concurrent_limit: int = 5,
) -> FakeAiProvider:
    provider = FakeAiProvider()
    settings = replace(
        client.app.state.settings,
        ai_daily_user_limit=user_limit,
        ai_daily_global_limit=global_limit,
        ai_max_concurrent_requests=concurrent_limit,
    )
    client.app.state.ai_generation_service = AiGenerationService(
        settings,
        provider,
    )
    return provider


def _headers(client: TestClient, key: str) -> dict[str, str]:
    response = client.post("/auth/dev-login", json={"dev_user_key": key})
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def _request_with_new_id() -> dict[str, Any]:
    body = request_body()
    body["request_id"] = str(uuid.uuid4())
    return body


def test_deepseek_configuration_requires_key_and_model(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.delenv("DEEPSEEK_API_KEY", raising=False)
    monkeypatch.delenv("REBIRTH_AI_MODEL", raising=False)
    with pytest.raises(RuntimeError):
        load_settings(
            environment="development",
            jwt_secret="test-secret",
            ai_provider="deepseek",
            deepseek_api_key=None,
            ai_model="deepseek-chat",
        )
    with pytest.raises(RuntimeError):
        load_settings(
            environment="development",
            jwt_secret="test-secret",
            ai_provider="deepseek",
            deepseek_api_key="secret",
            ai_model=None,
        )


def test_deepseek_mock_success_uses_json_mode_and_reports_usage() -> None:
    client = _DeepSeekClient()
    generation = _generate(_deepseek_provider(client))
    assert generation.provider == "deepseek"
    assert generation.model == "deepseek-chat"
    assert generation.total_tokens == 48
    assert generation.structured_output["title"] == "Weekly reflection"
    assert client.calls == 1
    assert client.kwargs is not None
    assert client.kwargs["path"] == "/chat/completions"
    assert client.kwargs["json"]["response_format"] == {"type": "json_object"}
    assert client.kwargs["json"]["stream"] is False


@pytest.mark.parametrize(
    ("client", "code", "status"),
    [
        (
            _DeepSeekClient(
                error=httpx.ReadTimeout(
                    "timeout",
                    request=httpx.Request("POST", "https://api.deepseek.com"),
                )
            ),
            "provider_timeout",
            504,
        ),
        (_DeepSeekClient(status_code=401), "provider_auth_failed", 502),
        (_DeepSeekClient(status_code=429), "provider_rate_limited", 429),
    ],
)
def test_deepseek_errors_are_controlled(
    client: _DeepSeekClient,
    code: str,
    status: int,
) -> None:
    with pytest.raises(Exception) as raised:
        _generate(_deepseek_provider(client))
    assert getattr(raised.value, "code", None) == code
    assert getattr(raised.value, "status_code", None) == status


def test_deepseek_success_is_charged_once_and_replayed_from_ledger(
    client: TestClient,
) -> None:
    remote = _DeepSeekClient()
    settings = replace(
        client.app.state.settings,
        ai_provider="deepseek",
        deepseek_api_key="deepseek-test-secret",
        ai_model="deepseek-chat",
    )
    client.app.state.ai_generation_service = AiGenerationService(
        settings,
        DeepSeekProvider(settings, client=remote),
    )
    headers = _headers(client, "ai-operations-success")
    body = _request_with_new_id()

    first = client.post(
        "/ai/reports/weekly/generate",
        headers=headers,
        json=body,
    )
    replay = client.post(
        "/ai/reports/weekly/generate",
        headers=headers,
        json=body,
    )

    assert first.status_code == replay.status_code == 200
    assert first.json() == replay.json()
    assert remote.calls == 1
    with client.app.state.database.session_factory() as session:
        generation = session.scalar(
            select(AiGenerationRequest).where(
                AiGenerationRequest.request_id == body["request_id"]
            )
        )
        usage = session.scalar(
            select(AiUsageRecord).where(
                AiUsageRecord.request_id == body["request_id"]
            )
        )
        assert generation is not None
        assert generation.status == "completed"
        assert generation.provider == "deepseek"
        assert generation.model == "deepseek-chat"
        assert generation.lease_expires_at is None
        assert usage is not None
        assert usage.status == "completed"
        assert usage.provider == "deepseek"
        assert usage.model == "deepseek-chat"
        assert usage.input_tokens == 31
        assert usage.output_tokens == 17
        assert usage.total_tokens == 48
        assert usage.lease_expires_at is None


@pytest.mark.parametrize(
    ("remote", "code", "status"),
    [
        (_DeepSeekClient(status_code=401), "provider_auth_failed", 502),
        (
            _DeepSeekClient(
                error=httpx.ReadTimeout(
                    "timeout",
                    request=httpx.Request("POST", "https://api.deepseek.com"),
                )
            ),
            "provider_timeout",
            504,
        ),
        (
            _DeepSeekClient(
                error=httpx.ConnectError(
                    "unavailable",
                    request=httpx.Request("POST", "https://api.deepseek.com"),
                )
            ),
            "provider_unavailable",
            503,
        ),
    ],
)
def test_deepseek_incidents_are_terminal_release_leases_and_replay_once(
    client: TestClient,
    remote: _DeepSeekClient,
    code: str,
    status: int,
) -> None:
    settings = replace(
        client.app.state.settings,
        ai_provider="deepseek",
        deepseek_api_key="deepseek-test-secret",
        ai_model="deepseek-chat",
    )
    client.app.state.ai_generation_service = AiGenerationService(
        settings,
        DeepSeekProvider(settings, client=remote),
    )
    headers = _headers(client, f"ai-operations-{code}")
    body = _request_with_new_id()

    first = client.post(
        "/ai/reports/weekly/generate",
        headers=headers,
        json=body,
    )
    replay = client.post(
        "/ai/reports/weekly/generate",
        headers=headers,
        json=body,
    )

    assert first.status_code == replay.status_code == status
    assert first.json()["detail"]["code"] == code
    assert replay.json()["detail"]["code"] == code
    assert remote.calls == 1
    with client.app.state.database.session_factory() as session:
        generation = session.scalar(
            select(AiGenerationRequest).where(
                AiGenerationRequest.request_id == body["request_id"]
            )
        )
        usage = session.scalar(
            select(AiUsageRecord).where(
                AiUsageRecord.request_id == body["request_id"]
            )
        )
        assert generation is not None
        assert generation.status == "failed"
        assert generation.error_code == code
        assert generation.lease_expires_at is None
        assert usage is not None
        if code == "provider_timeout":
            assert usage.status == "processing"
            assert usage.lease_expires_at is not None
            assert usage.completed_at is None
            assert usage.reserved_tokens > 0
        else:
            assert usage.status == "failed"
            assert usage.lease_expires_at is None
            assert usage.completed_at is not None
            assert usage.reserved_tokens == 0
        assert usage.input_tokens is None
        assert usage.output_tokens is None
        assert usage.total_tokens is None


def test_kill_switch_returns_ai_disabled_without_usage(
    client: TestClient,
    auth_headers: dict[str, str],
) -> None:
    response = client.post(
        "/ai/reports/weekly/generate",
        headers=auth_headers,
        json=_request_with_new_id(),
    )
    assert response.status_code == 503
    assert response.json()["detail"]["code"] == "ai_disabled"
    with client.app.state.database.session_factory() as session:
        assert (
            session.scalar(select(func.count()).select_from(AiGenerationRequest))
            == 0
        )
        assert session.scalar(select(func.count()).select_from(AiUsageRecord)) == 0


def test_user_daily_limit_blocks_provider_and_isolates_users(
    client: TestClient,
) -> None:
    provider = _set_fake_service(client, user_limit=1)
    user_a = _headers(client, "ai-cost-user-a")
    user_b = _headers(client, "ai-cost-user-b")
    assert client.post(
        "/ai/reports/weekly/generate",
        headers=user_a,
        json=_request_with_new_id(),
    ).status_code == 200
    limited = client.post(
        "/ai/reports/weekly/generate",
        headers=user_a,
        json=_request_with_new_id(),
    )
    assert limited.status_code == 429
    assert limited.json()["detail"]["code"] == "usage_limit_reached"
    assert client.post(
        "/ai/reports/weekly/generate",
        headers=user_b,
        json=_request_with_new_id(),
    ).status_code == 200
    assert provider.calls == 2


def test_global_daily_limit_blocks_second_user(client: TestClient) -> None:
    provider = _set_fake_service(client, global_limit=1)
    user_a = _headers(client, "ai-global-user-a")
    user_b = _headers(client, "ai-global-user-b")
    assert client.post(
        "/ai/reports/weekly/generate",
        headers=user_a,
        json=_request_with_new_id(),
    ).status_code == 200
    response = client.post(
        "/ai/reports/weekly/generate",
        headers=user_b,
        json=_request_with_new_id(),
    )
    assert response.status_code == 429
    assert response.json()["detail"]["code"] == "usage_limit_reached"
    assert provider.calls == 1


def test_concurrency_limit_blocks_provider(
    client: TestClient,
    auth_headers: dict[str, str],
) -> None:
    provider = _set_fake_service(client, concurrent_limit=1)
    now = time.time_ns() // 1_000_000
    with client.app.state.database.session_factory() as session:
        user_id = session.scalar(select(CloudUser.id))
        session.add(
            AiUsageRecord(
                id=str(uuid.uuid4()),
                user_id=user_id,
                request_id=str(uuid.uuid4()),
                provider="fake",
                model="deterministic-test-provider",
                request_type="weekly_report",
                input_tokens=None,
                output_tokens=None,
                total_tokens=None,
                status="processing",
                created_at=now,
                updated_at=now,
                lease_expires_at=now + 60_000,
                completed_at=None,
            )
        )
        session.commit()
    response = client.post(
        "/ai/reports/weekly/generate",
        headers=auth_headers,
        json=_request_with_new_id(),
    )
    assert response.status_code == 429
    assert response.json()["detail"]["code"] == "usage_limit_reached"
    assert provider.calls == 0


def test_usage_ledger_has_no_prompt_or_output_columns(client: TestClient) -> None:
    columns = {
        item["name"]
        for item in inspect(client.app.state.database.engine).get_columns(
            "ai_usage_records"
        )
    }
    assert not columns.intersection(
        {"prompt", "payload", "journal", "health", "report_content", "output"}
    )


def test_ai_usage_migration_upgrade_downgrade_and_reupgrade(
    tmp_path: Any,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    database_file = tmp_path / "ai-cost-migration.sqlite"
    database_url = f"sqlite:///{database_file.as_posix()}"
    monkeypatch.setenv("REBIRTH_DATABASE_URL", database_url)
    config = Config("alembic.ini")
    command.upgrade(config, "20260731_0006")
    engine = create_engine(database_url)
    try:
        assert "ai_usage_records" not in inspect(engine).get_table_names()
        command.upgrade(config, "head")
        assert {
            "ai_usage_controls",
            "ai_usage_records",
        }.issubset(inspect(engine).get_table_names())
        assert {
            "reserved_tokens",
            "charged_tokens",
            "accounting_source",
        }.issubset(
            {
                column["name"]
                for column in inspect(engine).get_columns("ai_usage_records")
            }
        )
        command.downgrade(config, "20260812_0008")
        assert not {
            "reserved_tokens",
            "charged_tokens",
            "accounting_source",
        }.intersection(
            {
                column["name"]
                for column in inspect(engine).get_columns("ai_usage_records")
            }
        )
        command.upgrade(config, "head")
        assert "charged_tokens" in {
            column["name"]
            for column in inspect(engine).get_columns("ai_usage_records")
        }
        command.downgrade(config, "20260731_0006")
        assert "ai_usage_records" not in inspect(engine).get_table_names()
        command.upgrade(config, "head")
        assert "ai_usage_records" in inspect(engine).get_table_names()
    finally:
        engine.dispose()


def test_logs_exclude_key_token_and_prompt(
    client: TestClient,
    auth_headers: dict[str, str],
    caplog: pytest.LogCaptureFixture,
) -> None:
    api_key = "deepseek-secret-must-never-be-logged"
    remote = _DeepSeekClient()
    settings = replace(
        client.app.state.settings,
        ai_provider="deepseek",
        deepseek_api_key=api_key,
        ai_model="deepseek-chat",
    )
    client.app.state.ai_generation_service = AiGenerationService(
        settings,
        DeepSeekProvider(settings, client=remote),
    )
    caplog.set_level(logging.INFO, logger="rebirth.ai")
    body = _request_with_new_id()
    response = client.post(
        "/ai/reports/weekly/generate",
        headers=auth_headers,
        json=body,
    )
    assert response.status_code == 200
    logs = caplog.text
    assert api_key not in logs
    assert auth_headers["Authorization"].split(" ", 1)[1] not in logs
    assert json.dumps(body["payload"], sort_keys=True) not in logs
    assert "sleep_duration_minutes" not in logs
