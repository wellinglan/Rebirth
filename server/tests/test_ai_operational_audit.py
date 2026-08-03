from __future__ import annotations

import json
import logging
import sys
import uuid
from dataclasses import replace
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.ai.operations import (
    audit_usage,
    check_ledger_consistency,
    configuration_summary,
    monitor_operations,
)
from app.config import load_settings
from app.maintenance.rebirth_ai import main as operations_main
from app.models import AiGenerationRequest, AiUsageRecord, CloudUser


_DAY_MS = 24 * 60 * 60 * 1000
_NOW = 1_785_715_200_000


def test_audit_handles_empty_and_groups_provider_model_and_type(
    client: TestClient,
) -> None:
    with client.app.state.database.session_factory() as session:
        empty = audit_usage(session, days=7, now=_NOW)
        assert empty["groups"] == []
        assert empty["totals"]["request_count"] == 0
        user_id = _seed_user(session)
        _seed_pair(
            session,
            user_id=user_id,
            provider="deepseek",
            model="deepseek-chat",
            request_type="weekly_report",
            generation_status="completed",
            usage_status="completed",
            input_tokens=11,
            output_tokens=7,
            total_tokens=18,
        )
        _seed_pair(
            session,
            user_id=user_id,
            provider="openai",
            model="gpt-test",
            request_type="daily_insight",
            generation_status="failed",
            usage_status="failed",
            error_code="provider_timeout",
        )
        session.commit()
        report = audit_usage(session, days=7, now=_NOW)
    assert len(report["groups"]) == 2
    assert report["totals"] == {
        "request_count": 2,
        "success_count": 1,
        "failure_count": 1,
        "timeout_count": 1,
        "expired_count": 0,
        "token_input": 11,
        "token_output": 7,
        "token_total": 18,
    }
    serialized = json.dumps(report)
    assert user_id not in serialized
    assert "prompt" not in serialized.lower()


def test_configuration_summary_reports_readiness_without_secrets(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.delenv("DEEPSEEK_API_KEY", raising=False)
    settings = load_settings(
        environment="development",
        jwt_secret="configuration-test-secret",
        ai_provider="deepseek",
        deepseek_api_key=None,
        ai_model="deepseek-chat",
        validate_ai_provider_configuration=False,
    )
    missing = configuration_summary(settings)
    assert missing["status"] == "not_ready"
    assert missing["provider_ready"] is False

    configured = configuration_summary(
        replace(settings, deepseek_api_key="secret-never-print")
    )
    assert configured["status"] == "ok"
    assert configured["enabled"] is True
    output = json.dumps(configured)
    assert "secret-never-print" not in output
    assert "api_key" not in output.lower()
    assert "database" not in output.lower()


def test_budget_warning_and_exceeded_events_are_safe(client: TestClient) -> None:
    settings = replace(
        client.app.state.settings,
        ai_provider="fake",
        ai_daily_global_limit=10,
        ai_monthly_global_limit=10,
        ai_budget_warning_percent=80,
    )
    with client.app.state.database.session_factory() as session:
        user_id = _seed_user(session)
        for _ in range(8):
            _seed_usage(session, user_id=user_id)
        session.commit()
        warning = monitor_operations(
            session,
            settings=settings,
            window_minutes=60,
            now=_NOW,
            emit_logs=False,
        )
        for _ in range(2):
            _seed_usage(session, user_id=user_id)
        session.commit()
        exceeded = monitor_operations(
            session,
            settings=settings,
            window_minutes=60,
            now=_NOW,
            emit_logs=False,
        )
    assert {item["event"] for item in warning["events"]} == {
        "AI_USAGE_LIMIT_WARNING"
    }
    assert {item["event"] for item in exceeded["events"]} == {
        "AI_USAGE_LIMIT_EXCEEDED"
    }
    assert all(
        set(item) == {
            "event",
            "severity",
            "timestamp",
            "provider",
            "metric",
            "value",
            "threshold",
        }
        for item in exceeded["events"]
    )
    assert all(item["severity"] == "critical" for item in exceeded["events"])


def test_failure_timeout_expiry_and_lease_backlog_monitoring(
    client: TestClient,
) -> None:
    settings = replace(
        client.app.state.settings,
        ai_provider="fake",
        ai_failure_rate_warning_percent=20,
        ai_timeout_rate_warning_percent=10,
        ai_processing_backlog_warning=1,
    )
    with client.app.state.database.session_factory() as session:
        user_id = _seed_user(session)
        _seed_pair(
            session,
            user_id=user_id,
            generation_status="failed",
            usage_status="failed",
            error_code="provider_timeout",
        )
        _seed_pair(
            session,
            user_id=user_id,
            generation_status="failed",
            usage_status="failed",
            error_code="provider_unavailable",
        )
        _seed_pair(
            session,
            user_id=user_id,
            generation_status="completed",
            usage_status="completed",
        )
        _seed_pair(
            session,
            user_id=user_id,
            generation_status="outcome_unknown",
            usage_status="expired",
        )
        _seed_pair(
            session,
            user_id=user_id,
            generation_status="processing",
            usage_status="processing",
            lease_expires_at=_NOW - 1,
        )
        session.commit()
        report = monitor_operations(
            session,
            settings=settings,
            window_minutes=60,
            now=_NOW,
            emit_logs=False,
        )
    events = {item["event"] for item in report["events"]}
    assert "AI_PROVIDER_FAILURE_RATE_HIGH" in events
    assert "AI_PROVIDER_TIMEOUT_RATE_HIGH" in events
    assert "AI_EXPIRED_GENERATION_DETECTED" in events
    assert "AI_PROCESSING_LEASE_BACKLOG" in events
    assert report["processing_lease_backlog"] == 1
    assert report["processing_lease_backlog_sources"] == {
        "generation_count": 1,
        "usage_count": 1,
    }


def test_ledger_check_detects_consistent_and_inconsistent_rows(
    client: TestClient,
) -> None:
    with client.app.state.database.session_factory() as session:
        user_id = _seed_user(session)
        _seed_pair(
            session,
            user_id=user_id,
            generation_status="completed",
            usage_status="completed",
            input_tokens=4,
            output_tokens=6,
            total_tokens=10,
        )
        session.commit()
        consistent = check_ledger_consistency(session, days=7, now=_NOW)
        assert consistent["status"] == "ok"
        assert consistent["read_only"] is True

        _seed_generation(
            session,
            user_id=user_id,
            generation_status="completed",
        )
        _seed_usage(
            session,
            user_id=user_id,
            input_tokens=2,
            output_tokens=3,
            total_tokens=99,
        )
        _seed_pair(
            session,
            user_id=user_id,
            generation_status="failed",
            usage_status="completed",
            error_code="provider_unavailable",
        )
        _seed_pair(
            session,
            user_id=user_id,
            generation_status="completed",
            usage_status="expired",
        )
        session.commit()
        inconsistent = check_ledger_consistency(session, days=7, now=_NOW)
    assert inconsistent["status"] == "inconsistent"
    assert inconsistent["anomalies"]["generation_without_usage_count"] == 1
    assert inconsistent["anomalies"]["usage_without_generation_count"] == 1
    assert inconsistent["anomalies"]["token_total_mismatch_count"] == 1
    assert inconsistent["anomalies"]["failed_state_mismatch_count"] == 1
    assert inconsistent["anomalies"]["expired_state_mismatch_count"] == 1


def test_ledger_check_links_rows_across_utc_window_boundaries(
    client: TestClient,
) -> None:
    start = (_NOW // _DAY_MS - 7 + 1) * _DAY_MS
    with client.app.state.database.session_factory() as session:
        user_id = _seed_user(session)
        _seed_pair(
            session,
            user_id=user_id,
            generation_status="completed",
            usage_status="completed",
            generation_created_at=start - 1,
            usage_created_at=start,
        )
        _seed_pair(
            session,
            user_id=user_id,
            generation_status="completed",
            usage_status="completed",
            generation_created_at=_NOW,
            usage_created_at=_NOW + 1,
        )
        session.commit()
        report = check_ledger_consistency(session, days=7, now=_NOW)
    assert report["status"] == "ok"
    assert report["anomalies"]["generation_without_usage_count"] == 0
    assert report["anomalies"]["usage_without_generation_count"] == 0


def test_monitor_logs_exclude_prompt_secret_token_and_user_content(
    client: TestClient,
    caplog: pytest.LogCaptureFixture,
) -> None:
    settings = replace(
        client.app.state.settings,
        ai_provider="fake",
        ai_daily_global_limit=1,
        ai_monthly_global_limit=1,
        deepseek_api_key="secret-must-not-appear",
    )
    with client.app.state.database.session_factory() as session:
        user_id = _seed_user(session)
        _seed_usage(session, user_id=user_id)
        session.commit()
        with caplog.at_level(logging.INFO, logger="rebirth.ai"):
            monitor_operations(
                session,
                settings=settings,
                window_minutes=60,
                now=_NOW,
            )
    output = caplog.text.lower()
    assert "ai_usage_limit_exceeded" in output
    for forbidden in (
        "secret-must-not-appear",
        "authorization",
        "token",
        "prompt",
        "journal",
        "health",
        user_id,
    ):
        assert forbidden not in output


def test_cli_audit_defaults_to_seven_days_and_config_is_safe(
    tmp_path: object,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    database_file = tmp_path / "operations-cli.sqlite"
    database_url = f"sqlite:///{database_file.as_posix()}"
    from app.database import Database

    database = Database(database_url)
    database.create_schema()
    database.engine.dispose()
    monkeypatch.setenv("REBIRTH_DATABASE_URL", database_url)
    monkeypatch.setenv("REBIRTH_AI_PROVIDER", "disabled")
    monkeypatch.setattr(sys, "argv", ["rebirth_ai", "audit"])
    assert operations_main() == 0
    audit = json.loads(capsys.readouterr().out)
    assert audit["days"] == 7

    monkeypatch.setenv("REBIRTH_AI_PROVIDER", "deepseek")
    monkeypatch.setenv("REBIRTH_AI_MODEL", "deepseek-chat")
    monkeypatch.delenv("DEEPSEEK_API_KEY", raising=False)
    monkeypatch.setattr(sys, "argv", ["rebirth_ai", "config-check"])
    assert operations_main() == 0
    missing = json.loads(capsys.readouterr().out)
    assert missing["status"] == "not_ready"

    monkeypatch.setenv("DEEPSEEK_API_KEY", "cli-secret-never-print")
    assert operations_main() == 0
    config = capsys.readouterr().out
    assert "cli-secret-never-print" not in config
    assert "database_url" not in config


def test_operations_add_no_api_flutter_schema_or_migration() -> None:
    repository = Path(__file__).resolve().parents[2]
    router = (repository / "server/app/routers/ai.py").read_text(
        encoding="utf-8"
    )
    database = (repository / "lib/core/database/app_database.dart").read_text(
        encoding="utf-8"
    )
    versions = {
        path.name
        for path in (repository / "server/alembic/versions").glob("*.py")
    }
    runbook = (repository / "docs/44_AI_OPERATOR_RUNBOOK.md").read_text(
        encoding="utf-8"
    )
    assert "maintenance.rebirth_ai" not in router
    assert "usage/audit" not in router
    assert "int get schemaVersion => 9;" in database
    assert "20260801_0007_ai_provider_cost_safety.py" in versions
    assert not any("14a3" in name.lower() for name in versions)
    assert all(
        section in runbook
        for section in (
            "Deploy Or Change A Provider",
            "Change Usage Limits",
            "Disable AI",
            "Restore AI",
            "Provider Failure Or Timeout",
            "Budget Exhaustion",
            "Ledger And Database Diagnostics",
            "Rollback",
            "Incident Log Location And Privacy",
        )
    )


def test_operations_acceptance_docs_preserve_incident_boundaries() -> None:
    repository = Path(__file__).resolve().parents[2]
    runbook = (repository / "docs/44_AI_OPERATOR_RUNBOOK.md").read_text(
        encoding="utf-8"
    )
    matrix = (
        repository
        / "docs/manual_tests/49_ai_operations_acceptance.md"
    ).read_text(encoding="utf-8")
    normalized_runbook = " ".join(runbook.split())

    assert "Rotate A Provider Secret" in runbook
    assert "Provider-confirmed timeout is a terminal" in normalized_runbook
    assert "client network interruption" in normalized_runbook
    assert "do not change Alpha firewall or DNS" in matrix
    assert (
        "ghcr.io/wellinglan/rebirth-api:"
        "5932964873e7ae1f4495b431929d65429f05f29b"
        in matrix
    )
    result_counts = {
        result: matrix.count(f"| {result} |")
        for result in ("PASS", "FAIL", "NOT EXECUTED")
    }
    assert sum(result_counts.values()) == 72
    for result, count in result_counts.items():
        assert f"- {result}: `{count}`" in matrix

    all_passed = result_counts == {"PASS": 72, "FAIL": 0, "NOT EXECUTED": 0}
    expected_gate = "CLOSED" if all_passed else "OPEN"
    assert f"AI Usage Audit Gate: `{expected_gate}`" in matrix
    assert f"AI Operation Safety Gate: `{expected_gate}`" in matrix
    if all_passed:
        assert "Status: `PASS`" in matrix
    else:
        assert "Status: `IN PROGRESS`" in matrix or "Status: `SUSPENDED`" in matrix


def test_cli_database_failure_does_not_print_connection_details(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    connection_detail = "".join(
        ("postgresql://", "operator:", "credential-marker@", "private-host/db")
    )

    class _FailingDatabase:
        def __init__(self, _: str) -> None:
            raise Exception(connection_detail)

    monkeypatch.setenv("REBIRTH_AI_PROVIDER", "disabled")
    monkeypatch.setattr(sys, "argv", ["rebirth_ai", "audit"])
    monkeypatch.setattr(
        "app.maintenance.rebirth_ai.Database", _FailingDatabase
    )
    assert operations_main() == 1
    output = capsys.readouterr()
    assert output.out == ""
    assert json.loads(output.err) == {
        "status": "error",
        "error_code": "operation_failed",
    }
    assert "credential-marker" not in output.err
    assert "private-host" not in output.err


def _seed_user(session: object) -> str:
    user_id = str(uuid.uuid4())
    session.add(
        CloudUser(
            id=user_id,
            display_name="Operations Test",
            created_at=_NOW - 1000,
            updated_at=_NOW - 1000,
            deleted_at=None,
        )
    )
    session.flush()
    return user_id


def _seed_pair(
    session: object,
    *,
    user_id: str,
    provider: str = "fake",
    model: str = "test-model",
    request_type: str = "weekly_report",
    generation_status: str,
    usage_status: str,
    error_code: str | None = None,
    input_tokens: int | None = None,
    output_tokens: int | None = None,
    total_tokens: int | None = None,
    lease_expires_at: int | None = None,
    generation_created_at: int = _NOW - 1000,
    usage_created_at: int = _NOW - 1000,
) -> None:
    request_id = str(uuid.uuid4())
    _seed_generation(
        session,
        user_id=user_id,
        request_id=request_id,
        provider=provider,
        model=model,
        request_type=request_type,
        generation_status=generation_status,
        error_code=error_code,
        lease_expires_at=lease_expires_at,
        created_at=generation_created_at,
    )
    _seed_usage(
        session,
        user_id=user_id,
        request_id=request_id,
        provider=provider,
        model=model,
        request_type=request_type,
        usage_status=usage_status,
        input_tokens=input_tokens,
        output_tokens=output_tokens,
        total_tokens=total_tokens,
        lease_expires_at=lease_expires_at,
        created_at=usage_created_at,
    )


def _seed_generation(
    session: object,
    *,
    user_id: str,
    request_id: str | None = None,
    provider: str = "fake",
    model: str = "test-model",
    request_type: str = "weekly_report",
    generation_status: str,
    error_code: str | None = None,
    lease_expires_at: int | None = None,
    created_at: int = _NOW - 1000,
) -> None:
    request_id = request_id or str(uuid.uuid4())
    session.add(
        AiGenerationRequest(
            id=str(uuid.uuid4()),
            user_id=user_id,
            request_id=request_id,
            input_hash="a" * 64,
            report_type=request_type,
            prompt_version="test-v1",
            status=generation_status,
            provider=provider,
            model=model,
            output_schema_version=1 if generation_status == "completed" else None,
            report_content=None,
            structured_output_json=None,
            error_code=error_code,
            created_at=created_at,
            updated_at=_NOW - 1000,
            lease_expires_at=lease_expires_at,
            result_expires_at=None,
            dedupe_expires_at=_NOW + _DAY_MS,
            result_purged_at=None,
        )
    )


def _seed_usage(
    session: object,
    *,
    user_id: str,
    request_id: str | None = None,
    provider: str = "fake",
    model: str = "test-model",
    request_type: str = "weekly_report",
    usage_status: str = "completed",
    input_tokens: int | None = None,
    output_tokens: int | None = None,
    total_tokens: int | None = None,
    lease_expires_at: int | None = None,
    created_at: int = _NOW - 1000,
) -> None:
    session.add(
        AiUsageRecord(
            id=str(uuid.uuid4()),
            user_id=user_id,
            request_id=request_id or str(uuid.uuid4()),
            provider=provider,
            model=model,
            request_type=request_type,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            total_tokens=total_tokens,
            status=usage_status,
            created_at=created_at,
            updated_at=_NOW - 1000,
            lease_expires_at=lease_expires_at,
            completed_at=(
                None if usage_status == "processing" else _NOW - 1000
            ),
        )
    )
