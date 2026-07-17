from __future__ import annotations

import json
import logging
import sys
from copy import deepcopy
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.ai.canonical import input_hash
from app.ai.ledger import AiRequestLedger
from app.ai.providers import FakeAiProvider
from app.ai.schemas import AiWeeklyPayload
from app.ai.service import AiGenerationService
from app.config import load_settings
from app.maintenance.ai_ledger_cleanup import main as cleanup_main
from app.models import AiGenerationRequest
from tests.test_ai_gateway import request_body, use_fake


_AI_ENV_NAMES = (
    "REBIRTH_AI_TIMEOUT_SECONDS",
    "REBIRTH_AI_MAX_OUTPUT_TOKENS",
    "REBIRTH_AI_RESULT_RETENTION_HOURS",
    "REBIRTH_AI_DEDUPE_RETENTION_DAYS",
    "REBIRTH_AI_PROCESSING_LEASE_MINUTES",
)


def _clean_ai_env(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in _AI_ENV_NAMES:
        monkeypatch.delenv(name, raising=False)


def test_default_ai_operational_settings_are_valid(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _clean_ai_env(monkeypatch)
    settings = load_settings(environment="development", jwt_secret="test-secret")
    assert settings.ai_timeout_seconds == 90
    assert settings.ai_processing_lease_minutes == 5
    assert settings.ai_result_retention_hours == 24
    assert settings.ai_dedupe_retention_days == 30


@pytest.mark.parametrize(
    ("values", "expected_name"),
    [
        (
            {
                "REBIRTH_AI_TIMEOUT_SECONDS": "300",
                "REBIRTH_AI_PROCESSING_LEASE_MINUTES": "5",
            },
            "REBIRTH_AI_PROCESSING_LEASE_MINUTES",
        ),
        (
            {
                "REBIRTH_AI_TIMEOUT_SECONDS": "280",
                "REBIRTH_AI_PROCESSING_LEASE_MINUTES": "5",
            },
            "REBIRTH_AI_PROCESSING_LEASE_MINUTES",
        ),
        (
            {
                "REBIRTH_AI_RESULT_RETENTION_HOURS": "49",
                "REBIRTH_AI_DEDUPE_RETENTION_DAYS": "2",
            },
            "REBIRTH_AI_DEDUPE_RETENTION_DAYS",
        ),
        (
            {
                "REBIRTH_AI_PROCESSING_LEASE_MINUTES": "2880",
                "REBIRTH_AI_DEDUPE_RETENTION_DAYS": "2",
            },
            "REBIRTH_AI_DEDUPE_RETENTION_DAYS",
        ),
    ],
)
def test_invalid_ai_setting_relationships_fail_at_startup(
    monkeypatch: pytest.MonkeyPatch,
    values: dict[str, str],
    expected_name: str,
) -> None:
    _clean_ai_env(monkeypatch)
    for name, value in values.items():
        monkeypatch.setenv(name, value)
    with pytest.raises(RuntimeError) as error:
        load_settings(environment="development", jwt_secret="test-secret")
    assert expected_name in str(error.value)


@pytest.mark.parametrize("value", ["0", "-1", "NaN", "Infinity", "-Infinity"])
def test_timeout_must_be_finite_and_positive(
    monkeypatch: pytest.MonkeyPatch, value: str
) -> None:
    _clean_ai_env(monkeypatch)
    monkeypatch.setenv("REBIRTH_AI_TIMEOUT_SECONDS", value)
    with pytest.raises(RuntimeError) as error:
        load_settings(environment="development", jwt_secret="test-secret")
    assert "REBIRTH_AI_TIMEOUT_SECONDS" in str(error.value)


@pytest.mark.parametrize(
    "name",
    [
        "REBIRTH_AI_MAX_OUTPUT_TOKENS",
        "REBIRTH_AI_RESULT_RETENTION_HOURS",
        "REBIRTH_AI_DEDUPE_RETENTION_DAYS",
        "REBIRTH_AI_PROCESSING_LEASE_MINUTES",
    ],
)
@pytest.mark.parametrize("value", ["0", "-1", "not-a-number"])
def test_integer_ai_settings_must_be_positive(
    monkeypatch: pytest.MonkeyPatch, name: str, value: str
) -> None:
    _clean_ai_env(monkeypatch)
    monkeypatch.setenv(name, value)
    with pytest.raises(RuntimeError) as error:
        load_settings(environment="development", jwt_secret="test-secret")
    assert name in str(error.value)


def test_ai_setting_boundary_values_are_allowed(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _clean_ai_env(monkeypatch)
    monkeypatch.setenv("REBIRTH_AI_TIMEOUT_SECONDS", "270")
    monkeypatch.setenv("REBIRTH_AI_PROCESSING_LEASE_MINUTES", "5")
    monkeypatch.setenv("REBIRTH_AI_RESULT_RETENTION_HOURS", "24")
    monkeypatch.setenv("REBIRTH_AI_DEDUPE_RETENTION_DAYS", "1")
    settings = load_settings(environment="development", jwt_secret="test-secret")
    assert settings.ai_timeout_seconds == 270
    assert settings.ai_dedupe_retention_days == 1


def test_generate_openapi_declares_202_and_controlled_errors(
    client: TestClient,
) -> None:
    schema = client.get("/openapi.json").json()
    generate = schema["paths"]["/ai/reports/weekly/generate"]["post"]
    responses = generate["responses"]
    assert responses["200"]["content"]["application/json"]["schema"]["$ref"].endswith(
        "/AiWeeklyGenerateResponse"
    )
    assert responses["202"]["content"]["application/json"]["schema"]["$ref"].endswith(
        "/AiRequestStatusResponse"
    )
    for status in ("409", "410", "422", "429", "502", "503", "504"):
        assert responses[status]["content"]["application/json"]["schema"]["$ref"].endswith(
            "/AiErrorResponse"
        )
    status_get = schema["paths"]["/ai/requests/{request_id}"]["get"]["responses"]
    assert {"200", "401", "404"}.issubset(status_get)
    serialized = json.dumps(schema)
    assert "OPENAI_API_KEY" not in serialized
    assert "AiGenerationRequest" not in serialized


def test_ai_logs_have_stable_events_and_exclude_sensitive_content(
    client: TestClient,
    auth_headers: dict[str, str],
    caplog: pytest.LogCaptureFixture,
) -> None:
    sensitive_marker = "journal-secret-marker-8e"
    payload = deepcopy(request_body()["payload"])
    payload["scopes"].append("journal_reflections")
    payload["data"]["journal_reflections"] = [
        {
            "entry_date": payload["period"]["end_date"],
            "status": "completed",
            "most_important_accomplishment": sensitive_marker,
            "most_draining_event": None,
            "emotion_source": None,
            "learning": None,
            "tomorrow_adjustment": None,
        }
    ]
    body = request_body(payload)
    body["input_hash"] = input_hash(AiWeeklyPayload.model_validate(payload))
    provider = use_fake(client)
    with caplog.at_level(logging.INFO, logger="rebirth.ai"):
        first = client.post(
            "/ai/reports/weekly/generate", headers=auth_headers, json=body
        )
        replay = client.post(
            "/ai/reports/weekly/generate", headers=auth_headers, json=body
        )
        status = client.get(
            f"/ai/requests/{body['request_id']}", headers=auth_headers
        )
    assert first.status_code == replay.status_code == status.status_code == 200
    assert provider.calls == 1
    logs = "\n".join(caplog.messages)
    assert sensitive_marker not in logs
    assert auth_headers["Authorization"] not in logs
    assert body["input_hash"] not in logs
    assert body["input_hash"][:8] in logs
    assert "ai_request_claimed" in logs
    assert "ai_provider_started" in logs
    assert "ai_provider_completed" in logs
    assert "ai_request_replayed" in logs
    assert "ai_status_recovered" in logs
    for message in caplog.messages:
        record = json.loads(message)
        assert "pseudonymous_user_id" in record or record["event"].startswith(
            "ai_result_"
        ) or record["event"].startswith("ai_tombstone_")
        assert "payload" not in record
        assert "report_content" not in record
        assert "structured_output" not in record


def test_provider_failure_log_has_controlled_code_and_latency(
    client: TestClient,
    auth_headers: dict[str, str],
    caplog: pytest.LogCaptureFixture,
) -> None:
    client.app.state.ai_generation_service = AiGenerationService(
        client.app.state.settings, FakeAiProvider("timeout")
    )
    with caplog.at_level(logging.INFO, logger="rebirth.ai"):
        response = client.post(
            "/ai/reports/weekly/generate",
            headers=auth_headers,
            json=request_body(),
        )
    assert response.status_code == 504
    failed = [
        json.loads(message)
        for message in caplog.messages
        if "ai_provider_failed" in message
    ]
    assert failed[0]["error_code"] == "provider_timeout"
    assert failed[0]["latency_ms"] >= 0


def _prepare_cleanup_rows(
    client: TestClient, auth_headers: dict[str, str]
) -> tuple[AiGenerationRequest, AiGenerationRequest]:
    use_fake(client)
    first = request_body()
    second = request_body()
    second["request_id"] = "22222222-2222-4222-8222-222222222222"
    assert client.post(
        "/ai/reports/weekly/generate", headers=auth_headers, json=first
    ).status_code == 200
    assert client.post(
        "/ai/reports/weekly/generate", headers=auth_headers, json=second
    ).status_code == 200
    with client.app.state.database.session_factory() as session:
        rows = list(
            session.scalars(
                select(AiGenerationRequest).order_by(AiGenerationRequest.request_id)
            )
        )
        purge_row, delete_row = rows
        purge_row.result_expires_at = 100
        purge_row.dedupe_expires_at = 10_000
        delete_row.result_expires_at = 10_000
        delete_row.dedupe_expires_at = 100
        session.commit()
        session.expunge_all()
    return purge_row, delete_row


def test_cleanup_dry_run_execute_and_repeat_are_safe(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    purge_row, delete_row = _prepare_cleanup_rows(client, auth_headers)
    ledger = AiRequestLedger(client.app.state.settings)
    with client.app.state.database.session_factory() as session:
        dry_run = ledger.cleanup(session, now=500, dry_run=True)
    assert dry_run.result_candidate_count == 1
    assert dry_run.tombstone_candidate_count == 1
    assert dry_run.result_purge_count == dry_run.tombstone_delete_count == 0

    with client.app.state.database.session_factory() as session:
        assert session.get(AiGenerationRequest, purge_row.id).report_content is not None
        assert session.get(AiGenerationRequest, delete_row.id) is not None
        executed = ledger.cleanup(session, now=500)
    assert executed.result_purge_count == 1
    assert executed.tombstone_delete_count == 1

    with client.app.state.database.session_factory() as session:
        assert session.get(AiGenerationRequest, purge_row.id).report_content is None
        assert session.get(AiGenerationRequest, delete_row.id) is None
        repeated = ledger.cleanup(session, now=500)
    assert repeated.result_purge_count == repeated.tombstone_delete_count == 0


def test_cleanup_cli_outputs_counts_only(
    client: TestClient,
    auth_headers: dict[str, str],
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
    tmp_path: Path,
) -> None:
    purge_row, _ = _prepare_cleanup_rows(client, auth_headers)
    database_path = tmp_path / "cli.sqlite"
    client.app.state.database.engine.raw_connection().backup(
        __import__("sqlite3").connect(database_path)
    )
    monkeypatch.setenv(
        "REBIRTH_DATABASE_URL", f"sqlite:///{database_path.as_posix()}"
    )
    monkeypatch.setattr(sys, "argv", ["ai_ledger_cleanup", "--dry-run"])
    assert cleanup_main() == 0
    dry_run = json.loads(capsys.readouterr().out)
    assert dry_run["would_purge_result_count"] >= 1
    assert dry_run["actual_purge_result_count"] == 0

    monkeypatch.setattr(sys, "argv", ["ai_ledger_cleanup"])
    assert cleanup_main() == 0
    executed = json.loads(capsys.readouterr().out)
    assert executed["actual_purge_result_count"] >= 1
    output = json.dumps(executed)
    assert purge_row.request_id not in output
    assert purge_row.input_hash not in output
    assert "report_content" not in output

    assert cleanup_main() == 0
    repeated = json.loads(capsys.readouterr().out)
    assert repeated["actual_purge_result_count"] == 0
    assert repeated["actual_delete_tombstone_count"] == 0


def test_quality_gate_and_multiworker_assets_are_safe() -> None:
    repository_root = Path(__file__).resolve().parents[2]
    workflow = (repository_root / ".github/workflows/quality.yml").read_text(
        encoding="utf-8"
    )
    verifier = (
        repository_root / "server/scripts/verify_ai_multiworker.py"
    ).read_text(encoding="utf-8")
    compose = (repository_root / "server/docker-compose.test.yml").read_text(
        encoding="utf-8"
    )
    assert all(
        name in workflow
        for name in (
            "Server SQLite",
            "Server PostgreSQL Multiprocess And Multiworker",
            "Flutter Analyze And Test",
            "Android Debug Build",
        )
    )
    assert "OPENAI_API_KEY" not in workflow
    assert "E:\\" not in workflow
    assert '"--workers"' in verifier
    assert "ThreadPoolExecutor(max_workers=8)" in verifier
    assert "ai_provider_started" in verifier
    assert "POSTGRES_HOST_AUTH_METHOD: trust" in compose
    assert "tmpfs:" in compose
