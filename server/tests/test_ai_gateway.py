from __future__ import annotations

import copy
import asyncio
import json
from pathlib import Path
from types import SimpleNamespace
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.ai.canonical import canonical_json, input_hash, normalized_payload
from app.ai.prompts import get_prompt
from app.ai.providers import (
    FakeAiProvider,
    OpenAiResponsesProvider,
    ProviderPromptPayload,
    safety_identifier,
)
from app.ai.schemas import AiWeeklyPayload
from app.ai.service import AiGenerationService
from app.config import load_settings
from app.main import create_app


_ROOT = Path(__file__).resolve().parents[2]
_FIXTURE_PATH = _ROOT / "test" / "fixtures" / "ai_weekly_input_v1.json"
_HASH_PATH = (
    _ROOT / "test" / "fixtures" / "ai_weekly_input_v1_expected_hash.txt"
)


def fixture_payload() -> dict[str, Any]:
    return json.loads(_FIXTURE_PATH.read_text(encoding="utf-8"))


def expected_hash() -> str:
    return _HASH_PATH.read_text(encoding="utf-8").strip()


def request_body(payload: dict[str, Any] | None = None) -> dict[str, Any]:
    return {
        "request_id": "11111111-2222-4333-8444-555555555555",
        "input_hash": expected_hash(),
        "payload": payload or fixture_payload(),
    }


def use_fake(client: TestClient, scenario: str = "success") -> FakeAiProvider:
    provider = FakeAiProvider(scenario)
    settings = client.app.state.settings
    client.app.state.ai_generation_service = AiGenerationService(settings, provider)
    return provider


def test_default_provider_is_disabled(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("REBIRTH_AI_PROVIDER", raising=False)
    settings = load_settings(environment="development", jwt_secret="test-secret")
    assert settings.ai_provider == "disabled"


@pytest.mark.parametrize("missing", ["key", "model"])
def test_openai_requires_key_and_model(
    monkeypatch: pytest.MonkeyPatch, missing: str
) -> None:
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    monkeypatch.delenv("REBIRTH_AI_MODEL", raising=False)
    kwargs = {
        "environment": "development",
        "jwt_secret": "test-secret",
        "ai_provider": "openai",
        "openai_api_key": None if missing == "key" else "secret-value",
        "ai_model": None if missing == "model" else "configured-model",
    }
    with pytest.raises(RuntimeError) as error:
        load_settings(**kwargs)
    assert "secret-value" not in str(error.value)


def test_fake_is_development_only() -> None:
    with pytest.raises(RuntimeError):
        load_settings(
            environment="production",
            jwt_secret="test-secret",
            ai_provider="fake",
        )


def test_settings_repr_does_not_contain_api_key() -> None:
    settings = load_settings(
        environment="development",
        jwt_secret="test-secret",
        ai_provider="openai",
        openai_api_key="top-secret-provider-key",
        ai_model="configured-model",
    )
    assert "top-secret-provider-key" not in repr(settings)


def test_capabilities_require_auth(client: TestClient) -> None:
    response = client.get("/ai/capabilities")
    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "authentication_required"


def test_disabled_capabilities_are_safe(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    response = client.get("/ai/capabilities", headers=auth_headers)
    assert response.status_code == 200
    assert response.json() == {
        "enabled": False,
        "provider": "disabled",
        "provider_label": "Disabled",
        "model": None,
        "supported_report_types": ["daily_insight", "weekly_report"],
        "prompt_versions": ["daily-insight-v1", "weekly-report-v1"],
        "input_schema_version": 1,
        "output_schema_version": 1,
        "report_contracts": [
            {
                "report_type": "daily_insight",
                "prompt_versions": ["daily-insight-v1"],
                "input_schema_version": 1,
                "output_schema_version": 1,
                "period_kind": "single_day",
                "supported_scopes": [
                    "today_metrics",
                    "health_metrics",
                    "journal_reflections",
                ],
            },
            {
                "report_type": "weekly_report",
                "prompt_versions": ["weekly-report-v1"],
                "input_schema_version": 1,
                "output_schema_version": 1,
                "period_kind": "seven_days",
                "supported_scopes": [
                    "growth_summary",
                    "today_metrics",
                    "health_metrics",
                    "journal_reflections",
                ],
            },
        ],
        "streaming": False,
        "response_storage_requested": False,
        "durable_request_ledger": True,
        "request_status_recovery": True,
        "result_retention_hours": 24,
        "dedupe_retention_days": 30,
        "processing_lease_minutes": 5,
        "exactly_once_guaranteed": False,
    }
    assert "key" not in response.text.lower()


def test_fake_capabilities_are_enabled(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    use_fake(client)
    body = client.get("/ai/capabilities", headers=auth_headers).json()
    assert body["enabled"] is True
    assert body["provider"] == "fake"
    assert body["model"] == "deterministic-test-provider"


def test_shared_fixture_canonical_hash_matches_expected() -> None:
    payload = AiWeeklyPayload.model_validate(fixture_payload())
    assert input_hash(payload) == expected_hash()
    encoded = canonical_json(normalized_payload(payload))
    assert "\n" not in encoded
    assert "中文" in encoded


def test_order_does_not_change_hash() -> None:
    value = fixture_payload()
    value["scopes"].reverse()
    value["sources"].reverse()
    value["data"]["today_metrics"].reverse()
    assert input_hash(AiWeeklyPayload.model_validate(value)) == expected_hash()


def test_null_and_zero_have_different_hashes() -> None:
    zero = fixture_payload()
    null = copy.deepcopy(zero)
    null["data"]["today_metrics"][0]["research_minutes"] = None
    assert input_hash(AiWeeklyPayload.model_validate(zero)) != input_hash(
        AiWeeklyPayload.model_validate(null)
    )


def test_generation_requires_auth(client: TestClient) -> None:
    response = client.post("/ai/reports/weekly/generate", json=request_body())
    assert response.status_code == 401


def test_fake_generation_success_and_minimized_payload(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    provider = use_fake(client)
    response = client.post(
        "/ai/reports/weekly/generate", headers=auth_headers, json=request_body()
    )
    assert response.status_code == 200
    body = response.json()
    assert body["request_id"] == request_body()["request_id"]
    assert body["input_hash"] == expected_hash()
    assert body["provider"] == "fake"
    assert body["model"] == "deterministic-test-provider"
    assert body["output_schema_version"] == 1
    assert body["report_content"].startswith("# 开发测试每周回顾")
    assert body["structured_output"]["observations"]
    forwarded = provider.last_payload.to_json_value()
    assert set(forwarded) == {
        "report_type",
        "prompt_version",
        "period",
        "scopes",
        "data",
    }
    assert "sources" not in forwarded
    assert "request_id" not in forwarded
    assert "input_hash" not in forwarded
    assert "user_id" not in forwarded
    assert "daily_note" not in json.dumps(forwarded)


def test_hash_mismatch_blocks_provider(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    provider = use_fake(client)
    body = request_body()
    body["input_hash"] = "0" * 64
    response = client.post(
        "/ai/reports/weekly/generate", headers=auth_headers, json=body
    )
    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "input_hash_mismatch"
    assert provider.calls == 0


@pytest.mark.parametrize(
    ("mutation", "code"),
    [
        (lambda value: value.update(schema_version=2), "invalid_input"),
        (lambda value: value.update(report_type="daily_insight"), "unsupported_report_type"),
        (lambda value: value.update(prompt_version="weekly-report-v2"), "unsupported_prompt_version"),
    ],
)
def test_unsupported_contract_blocks_provider(
    client: TestClient,
    auth_headers: dict[str, str],
    mutation: Any,
    code: str,
) -> None:
    provider = use_fake(client)
    payload = fixture_payload()
    mutation(payload)
    body = request_body(payload)
    body["input_hash"] = "1" * 64
    response = client.post(
        "/ai/reports/weekly/generate", headers=auth_headers, json=body
    )
    assert response.status_code == 422
    assert response.json()["detail"]["code"] == code
    assert provider.calls == 0


def test_unsupported_scope_blocks_provider(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    provider = use_fake(client)
    payload = fixture_payload()
    payload["scopes"].append("active_goals")
    response = client.post(
        "/ai/reports/weekly/generate",
        headers=auth_headers,
        json=request_body(payload),
    )
    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "unsupported_scope"
    assert provider.calls == 0


@pytest.mark.parametrize(
    "mutate",
    [
        lambda body: body.update(user_id="forbidden"),
        lambda body: body.update(model="forbidden"),
        lambda body: body.update(api_key="forbidden"),
        lambda body: body["payload"].update(extra="forbidden"),
        lambda body: body["payload"]["period"].update(extra="forbidden"),
        lambda body: body["payload"]["data"]["today_metrics"][0].update(
            daily_note="forbidden"
        ),
    ],
)
def test_extra_fields_are_rejected(
    client: TestClient,
    auth_headers: dict[str, str],
    mutate: Any,
) -> None:
    provider = use_fake(client)
    body = request_body()
    mutate(body)
    response = client.post(
        "/ai/reports/weekly/generate", headers=auth_headers, json=body
    )
    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "invalid_request"
    assert provider.calls == 0


@pytest.mark.parametrize(
    "mutate",
    [
        lambda body: body.update(request_id="not-a-uuid"),
        lambda body: body.update(input_hash="bad"),
        lambda body: body["payload"]["period"].update(end_date="2026-07-15"),
        lambda body: body["payload"]["period"].update(start_date="not-a-date"),
    ],
)
def test_invalid_values_are_rejected(
    client: TestClient, auth_headers: dict[str, str], mutate: Any
) -> None:
    provider = use_fake(client)
    body = request_body()
    mutate(body)
    response = client.post(
        "/ai/reports/weekly/generate", headers=auth_headers, json=body
    )
    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "invalid_request"
    assert provider.calls == 0


@pytest.mark.parametrize(
    ("scenario", "code", "status"),
    [
        ("timeout", "provider_timeout", 504),
        ("refusal", "provider_refused", 422),
        ("invalid", "response_invalid", 502),
        ("unavailable", "provider_unavailable", 503),
    ],
)
def test_fake_failures_are_controlled(
    client: TestClient,
    auth_headers: dict[str, str],
    scenario: str,
    code: str,
    status: int,
) -> None:
    use_fake(client, scenario)
    response = client.post(
        "/ai/reports/weekly/generate", headers=auth_headers, json=request_body()
    )
    assert response.status_code == status
    assert response.json()["detail"]["code"] == code
    assert "Traceback" not in response.text


def test_fake_output_is_deterministic() -> None:
    first = FakeAiProvider()
    second = FakeAiProvider()
    assert first.scenario == second.scenario == "success"


class _ResponsesMock:
    def __init__(self) -> None:
        self.kwargs: dict[str, Any] | None = None

    async def create(self, **kwargs: Any) -> Any:
        self.kwargs = kwargs
        output = {
            "title": "Weekly reflection",
            "summary": "A concise summary.",
            "observations": [],
            "suggestions": [],
            "data_limitations": [],
        }
        return SimpleNamespace(
            output_text=json.dumps(output), output=[], model="actual-model"
        )


def test_openai_adapter_uses_stateless_strict_responses_api() -> None:
    responses = _ResponsesMock()
    client = SimpleNamespace(responses=responses)
    settings = load_settings(
        environment="test",
        jwt_secret="test-secret",
        ai_provider="openai",
        openai_api_key="secret-not-forwarded",
        ai_model="configured-model",
    )
    provider = OpenAiResponsesProvider(settings, client=client)
    prompt = get_prompt("weekly_report", "weekly-report-v1")
    assert prompt is not None
    result = asyncio.run(
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
            safety_identifier="safe-hash",
        )
    )
    kwargs = responses.kwargs
    assert kwargs is not None
    assert kwargs["model"] == "configured-model"
    assert kwargs["store"] is False
    assert kwargs["stream"] is False
    assert kwargs["tools"] == []
    assert kwargs["max_output_tokens"] == 1600
    assert kwargs["timeout"] == 90
    assert kwargs["safety_identifier"] == "safe-hash"
    assert kwargs["text"]["format"]["strict"] is True
    assert kwargs["text"]["format"]["type"] == "json_schema"
    assert result.model == "actual-model"
    assert "secret-not-forwarded" not in json.dumps(kwargs)


def test_safety_identifier_is_stable_and_not_raw_user_id() -> None:
    first = safety_identifier("cloud-user-id", "production")
    second = safety_identifier("cloud-user-id", "production")
    assert first == second
    assert first != "cloud-user-id"
    assert len(first) == 64
