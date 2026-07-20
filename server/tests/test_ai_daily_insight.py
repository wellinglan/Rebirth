from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError
from sqlalchemy import inspect, select

from app.ai.canonical import canonical_json, input_hash, normalized_payload
from app.ai.prompts import get_prompt, render_daily_markdown
from app.ai.providers import FakeAiProvider
from app.ai.schemas import AiDailyPayload, AiDailyStructuredOutput
from app.ai.service import AiGenerationService
from app.models import AiGenerationRequest
from tests.test_ai_gateway import request_body as weekly_request_body


_ROOT = Path(__file__).resolve().parents[2]
_FIXTURE_PATH = _ROOT / "test" / "fixtures" / "ai_daily_insight_input_v1.json"
_HASH_PATH = (
    _ROOT / "test" / "fixtures" / "ai_daily_insight_input_v1_expected_hash.txt"
)
_SENSITIVE_MARKER = "DAILY敏感标记_仅供测试_9A"


def daily_fixture() -> dict[str, Any]:
    return json.loads(_FIXTURE_PATH.read_text(encoding="utf-8"))


def daily_expected_hash() -> str:
    return _HASH_PATH.read_text(encoding="utf-8").strip()


def daily_request_body(payload: dict[str, Any] | None = None) -> dict[str, Any]:
    value = payload or daily_fixture()
    return {
        "request_id": "11111111-2222-4333-8444-555555555555",
        "input_hash": input_hash(AiDailyPayload.model_validate(value)),
        "payload": value,
    }


def use_fake(client: TestClient, scenario: str = "success") -> FakeAiProvider:
    provider = FakeAiProvider(scenario)
    client.app.state.ai_generation_service = AiGenerationService(
        client.app.state.settings, provider
    )
    return provider


def replace_daily_scope_with_growth(payload: dict[str, Any]) -> None:
    payload["scopes"].remove("journal_reflections")
    payload["scopes"].append("growth_summary")
    del payload["data"]["journal_reflections"]


def test_daily_shared_fixture_hash_is_cross_language_stable() -> None:
    payload = AiDailyPayload.model_validate(daily_fixture())
    assert input_hash(payload) == daily_expected_hash()
    encoded = canonical_json(normalized_payload(payload))
    assert _SENSITIVE_MARKER in encoded
    assert '"research_minutes":0' in encoded
    assert '"learning_minutes":null' in encoded


def test_daily_hash_distinguishes_contract_identity_and_missing_states() -> None:
    fixture = daily_fixture()
    empty = copy.deepcopy(fixture)
    empty["data"]["today_metrics"] = []
    unselected = copy.deepcopy(empty)
    unselected["scopes"].remove("today_metrics")
    del unselected["data"]["today_metrics"]
    zero = input_hash(AiDailyPayload.model_validate(fixture))
    fixture["data"]["today_metrics"][0]["research_minutes"] = None
    null = input_hash(AiDailyPayload.model_validate(fixture))

    assert zero != null
    assert input_hash(AiDailyPayload.model_validate(empty)) != input_hash(
        AiDailyPayload.model_validate(unselected)
    )


@pytest.mark.parametrize(
    "mutate",
    [
        lambda value: value["period"].update(end_date="2026-07-21"),
        lambda value: value["scopes"].append("today_metrics"),
        lambda value: value["scopes"].remove("health_metrics"),
        lambda value: value["data"]["today_metrics"][0].update(
            record_date="2026-07-19"
        ),
        lambda value: value["data"]["today_metrics"].append(
            copy.deepcopy(value["data"]["today_metrics"][0])
        ),
        lambda value: value.update(extra="forbidden"),
        lambda value: value["data"]["today_metrics"][0].update(
            daily_note="forbidden"
        ),
    ],
)
def test_daily_schema_rejects_invalid_contracts(mutate: Any) -> None:
    payload = daily_fixture()
    mutate(payload)
    with pytest.raises(ValidationError):
        AiDailyPayload.model_validate(payload)


def test_capabilities_publish_typed_daily_and_weekly_contracts(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    body = client.get("/ai/capabilities", headers=auth_headers).json()
    contracts = {item["report_type"]: item for item in body["report_contracts"]}
    assert set(contracts) == {"daily_insight", "weekly_report"}
    assert contracts["daily_insight"] == {
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
    }
    assert contracts["weekly_report"]["period_kind"] == "seven_days"
    assert body["exactly_once_guaranteed"] is False


def test_daily_generate_requires_jwt(client: TestClient) -> None:
    response = client.post("/ai/reports/daily/generate", json=daily_request_body())
    assert response.status_code == 401


def test_daily_fake_success_minimizes_provider_payload_and_replays(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    provider = use_fake(client)
    first = client.post(
        "/ai/reports/daily/generate",
        headers=auth_headers,
        json=daily_request_body(),
    )
    second = client.post(
        "/ai/reports/daily/generate",
        headers=auth_headers,
        json=daily_request_body(),
    )
    assert first.status_code == second.status_code == 200
    assert first.json() == second.json()
    body = first.json()
    assert body["report_type"] == "daily_insight"
    assert body["prompt_version"] == "daily-insight-v1"
    assert body["structured_output"]["possible_factors"]
    assert body["report_content"].startswith("# Daily Insight")
    assert provider.calls == 1
    forwarded = provider.last_payload.to_json_value()
    assert set(forwarded) == {
        "report_type",
        "prompt_version",
        "period",
        "scopes",
        "data",
    }
    serialized = json.dumps(forwarded, ensure_ascii=False)
    for forbidden in (
        "sources",
        "request_id",
        "input_hash",
        "user_id",
        "daily_note",
        "growth_summary",
        "active_goals",
    ):
        assert forbidden not in serialized
    assert _SENSITIVE_MARKER in serialized

    status = client.get(
        f"/ai/requests/{daily_request_body()['request_id']}", headers=auth_headers
    )
    assert status.status_code == 200
    assert status.json()["structured_output"] == body["structured_output"]


def test_daily_selected_missing_is_not_omitted_and_zero_is_not_missing(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    provider = use_fake(client)
    payload = daily_fixture()
    payload["data"]["journal_reflections"] = []
    response = client.post(
        "/ai/reports/daily/generate",
        headers=auth_headers,
        json=daily_request_body(payload),
    )
    assert response.status_code == 200
    forwarded = provider.last_payload.to_json_value()
    assert forwarded["data"]["journal_reflections"] == []
    assert forwarded["data"]["health_metrics"][0]["water_intake_ml"] == 0
    limitations = response.json()["structured_output"]["data_limitations"]
    assert any("journal_reflections" in item for item in limitations)
    assert not any("health_metrics" in item for item in limitations)


@pytest.mark.parametrize(
    ("scenario", "code", "status"),
    [
        ("timeout", "provider_timeout", 504),
        ("refusal", "provider_refused", 422),
        ("invalid", "response_invalid", 502),
        ("unavailable", "provider_unavailable", 503),
    ],
)
def test_daily_fake_failures_are_controlled(
    client: TestClient,
    auth_headers: dict[str, str],
    scenario: str,
    code: str,
    status: int,
) -> None:
    provider = use_fake(client, scenario)
    response = client.post(
        "/ai/reports/daily/generate",
        headers=auth_headers,
        json=daily_request_body(),
    )
    assert response.status_code == status
    assert response.json()["detail"]["code"] == code
    assert provider.calls == 1


@pytest.mark.parametrize(
    ("mutation", "code"),
    [
        (lambda payload: payload.update(report_type="weekly_report"), "unsupported_report_type"),
        (lambda payload: payload.update(prompt_version="weekly-report-v1"), "unsupported_prompt_version"),
        (replace_daily_scope_with_growth, "unsupported_scope"),
    ],
)
def test_daily_contract_pairing_blocks_provider(
    client: TestClient,
    auth_headers: dict[str, str],
    mutation: Any,
    code: str,
) -> None:
    provider = use_fake(client)
    payload = daily_fixture()
    mutation(payload)
    body = {
        "request_id": daily_request_body()["request_id"],
        "input_hash": "1" * 64,
        "payload": payload,
    }
    response = client.post(
        "/ai/reports/daily/generate", headers=auth_headers, json=body
    )
    assert response.status_code == 422
    assert response.json()["detail"]["code"] == code
    assert provider.calls == 0


def test_daily_hash_mismatch_blocks_provider(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    provider = use_fake(client)
    body = daily_request_body()
    body["input_hash"] = "0" * 64
    response = client.post(
        "/ai/reports/daily/generate", headers=auth_headers, json=body
    )
    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "input_hash_mismatch"
    assert provider.calls == 0


def test_daily_and_weekly_same_request_id_conflict(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    provider = use_fake(client)
    assert client.post(
        "/ai/reports/daily/generate",
        headers=auth_headers,
        json=daily_request_body(),
    ).status_code == 200
    response = client.post(
        "/ai/reports/weekly/generate",
        headers=auth_headers,
        json=weekly_request_body(),
    )
    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "idempotency_conflict"
    assert provider.calls == 1


def test_daily_output_and_renderer_are_strict_and_stable() -> None:
    value = {
        "title": "Daily",
        "summary": "Summary",
        "observations": [{"statement": "Observed", "evidence": ["record"]}],
        "possible_factors": [{"factor": "Possible", "caveat": "Not causal"}],
        "tomorrow_adjustments": [{"action": "Try", "reason": "Optional"}],
        "data_limitations": ["One day only"],
    }
    output = AiDailyStructuredOutput.model_validate(value)
    markdown = render_daily_markdown(output)
    assert markdown.splitlines() == [
        "# Daily",
        "",
        "Summary",
        "",
        "## 今日观察",
        "- Observed（依据：record）",
        "",
        "## 可能相关因素",
        "- Possible（限制：Not causal）",
        "",
        "## 明日可选调整",
        "- Try：Optional",
        "",
        "## 数据限制",
        "- One day only",
    ]
    for mutation in (
        lambda item: item.update(extra=True),
        lambda item: item.update(title=" "),
        lambda item: item.update(summary=" "),
        lambda item: item["observations"][0].update(statement=" "),
        lambda item: item["possible_factors"][0].update(factor=" "),
        lambda item: item["possible_factors"][0].update(caveat=" "),
        lambda item: item["tomorrow_adjustments"][0].update(action=" "),
        lambda item: item["tomorrow_adjustments"][0].update(reason=" "),
        lambda item: item.update(observations=value["observations"] * 5),
        lambda item: item.update(possible_factors=value["possible_factors"] * 4),
        lambda item: item.update(tomorrow_adjustments=value["tomorrow_adjustments"] * 4),
        lambda item: item["possible_factors"][0].update(extra=True),
    ):
        invalid = copy.deepcopy(value)
        mutation(invalid)
        with pytest.raises(ValidationError):
            AiDailyStructuredOutput.model_validate(invalid)

    empty_sections = AiDailyStructuredOutput.model_validate(
        {
            "title": "Daily",
            "summary": "Summary",
            "observations": [],
            "possible_factors": [],
            "tomorrow_adjustments": [],
            "data_limitations": [],
        }
    )
    assert render_daily_markdown(empty_sections) == "# Daily\n\nSummary"


def test_prompt_registry_requires_report_and_prompt_pair() -> None:
    daily = get_prompt("daily_insight", "daily-insight-v1")
    weekly = get_prompt("weekly_report", "weekly-report-v1")
    assert daily is not None and daily.output_model is AiDailyStructuredOutput
    assert weekly is not None
    assert get_prompt("daily_insight", "weekly-report-v1") is None
    assert get_prompt("weekly_report", "daily-insight-v1") is None
    assert "untrusted user data" in daily.developer_instructions
    assert "Never claim causation from one day" in daily.developer_instructions


def test_daily_ledger_stores_no_input_contract_or_sources(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    use_fake(client)
    assert client.post(
        "/ai/reports/daily/generate",
        headers=auth_headers,
        json=daily_request_body(),
    ).status_code == 200
    with client.app.state.database.session_factory() as session:
        row = session.scalar(select(AiGenerationRequest))
        assert row is not None
        assert row.report_type == "daily_insight"
        serialized = " ".join(
            filter(None, [row.report_content, row.structured_output_json])
        )
        assert _SENSITIVE_MARKER not in serialized
        assert "today-fixture-9a" not in serialized
    columns = {
        item["name"]
        for item in inspect(client.app.state.database.engine).get_columns(
            "ai_generation_requests"
        )
    }
    assert {"payload", "canonical_json", "sources", "journal"}.isdisjoint(columns)


def test_daily_logging_excludes_sensitive_input_and_output(
    client: TestClient,
    auth_headers: dict[str, str],
    caplog: pytest.LogCaptureFixture,
) -> None:
    use_fake(client)
    body = daily_request_body()
    with caplog.at_level("INFO", logger="rebirth.ai"):
        response = client.post(
            "/ai/reports/daily/generate", headers=auth_headers, json=body
        )
    assert response.status_code == 200
    logs = caplog.text
    assert body["input_hash"][:8] in logs
    for forbidden in (
        _SENSITIVE_MARKER,
        body["input_hash"],
        "today-fixture-9a",
        "API Key",
        "Bearer ",
        response.json()["report_content"],
        json.dumps(response.json()["structured_output"]),
    ):
        assert forbidden not in logs


def test_openapi_declares_daily_endpoint_and_response_models(client: TestClient) -> None:
    schema = client.get("/openapi.json").json()
    operation = schema["paths"]["/ai/reports/daily/generate"]["post"]
    assert operation["responses"]["200"]["content"]["application/json"]
    for status in ("202", "409", "410", "422", "429", "502", "503", "504"):
        assert status in operation["responses"]
    assert "AiDailyGenerateRequest" in schema["components"]["schemas"]
    assert "AiDailyGenerateResponse" in schema["components"]["schemas"]
