from __future__ import annotations

import json
import sys

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.ai.feedback import feedback_audit
from app.maintenance.rebirth_ai import main as operations_main
from app.models import AiReportFeedback, SyncItem


REPORT_ID = "81111111-1111-4111-8111-111111111111"
VERSION_ID = "82222222-2222-4222-8222-222222222222"
FEEDBACK_ID = "83333333-3333-4333-8333-333333333333"
ORIGIN_ID = "84444444-4444-4444-8444-444444444444"


def _report_payload() -> dict[str, object]:
    return {
        "report_type": "weekly_report",
        "title": "Private weekly report",
        "period_start_date": "2026-08-03",
        "period_end_date": "2026-08-09",
        "report_status": "completed",
        "created_at": 1_786_496_400_000,
        "generation_source": "ai_coach",
        "sensitivity": "high",
        "quality": "unreviewed",
        "current_version": 1,
        "versions": [
            {
                "id": VERSION_ID,
                "version": 1,
                "status": "completed",
                "generation_source": "ai_coach",
                "content": "private report body",
                "sensitivity": "high",
                "quality": "unreviewed",
                "error_code": None,
                "created_at": 1_786_496_400_000,
                "completed_at": 1_786_496_400_100,
            }
        ],
    }


def _push_report(
    client: TestClient,
    headers: dict[str, str],
    device_id: str,
) -> None:
    response = client.post(
        "/sync/push",
        headers=headers,
        json={
            "device_id": device_id,
            "items": [
                {
                    "table": "ai_reports",
                    "id": REPORT_ID,
                    "payload": _report_payload(),
                    "updated_at": 1_786_496_400_200,
                    "deleted_at": None,
                    "origin_device_id": ORIGIN_ID,
                    "client_version": 0,
                }
            ],
        },
    )
    assert response.status_code == 200


def _write_body(**overrides: object) -> dict[str, object]:
    body: dict[str, object] = {
        "feedback_id": FEEDBACK_ID,
        "report_id": REPORT_ID,
        "report_version": 1,
        "report_type": "weekly_report",
        "helpfulness": "helpful",
        "reason_codes": [],
        "prompt_id": "weekly_report",
        "prompt_version": "weekly-report-v1",
        "expected_server_version": None,
    }
    body.update(overrides)
    return body


def test_feedback_requires_jwt_and_uses_report_ownership(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    assert client.get("/ai/report-feedback").status_code == 401
    missing = client.post(
        "/ai/report-feedback/upsert",
        headers=auth_headers,
        json=_write_body(),
    )
    assert missing.status_code == 409
    assert missing.json()["detail"]["code"] == "report_not_synced"

    _push_report(client, auth_headers, registered_device)
    ineligible = client.post(
        "/ai/report-feedback/upsert",
        headers=auth_headers,
        json=_write_body(report_version=2),
    )
    assert ineligible.status_code == 422
    assert ineligible.json()["detail"]["code"] == "report_version_not_eligible"

    created = client.post(
        "/ai/report-feedback/upsert",
        headers=auth_headers,
        json=_write_body(),
    )
    assert created.status_code == 200
    assert created.json()["outcome"] == "applied"
    assert created.json()["item"]["server_version"] == 1


def test_feedback_table_contains_no_report_body_or_provider_response() -> None:
    columns = set(AiReportFeedback.__table__.columns.keys())
    assert columns == {
        "id",
        "cloud_user_id",
        "report_record_id",
        "report_version_number",
        "report_type",
        "helpfulness",
        "reason_codes_json",
        "prompt_id",
        "prompt_version",
        "server_version",
        "created_at",
        "updated_at",
        "deleted_at",
    }


def test_feedback_validation_is_closed_and_has_no_free_text(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    _push_report(client, auth_headers, registered_device)
    for body in (
        _write_body(helpfulness="not_helpful", reason_codes=[]),
        _write_body(reason_codes=["custom_reason"]),
        _write_body(comment="free text must not be accepted"),
        _write_body(reason_codes=["too_generic", "not_actionable"]),
    ):
        response = client.post(
            "/ai/report-feedback/upsert",
            headers=auth_headers,
            json=body,
        )
        assert response.status_code == 422


def test_feedback_replay_occ_and_delete_are_deterministic(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    _push_report(client, auth_headers, registered_device)
    first = client.post(
        "/ai/report-feedback/upsert",
        headers=auth_headers,
        json=_write_body(),
    ).json()
    replay = client.post(
        "/ai/report-feedback/upsert",
        headers=auth_headers,
        json=_write_body(),
    ).json()
    assert replay == first

    changed = client.post(
        "/ai/report-feedback/upsert",
        headers=auth_headers,
        json=_write_body(
            helpfulness="not_helpful",
            reason_codes=["too_generic"],
            expected_server_version=1,
        ),
    ).json()
    assert changed["outcome"] == "applied"
    assert changed["item"]["server_version"] == 2

    stale = client.post(
        "/ai/report-feedback/upsert",
        headers=auth_headers,
        json=_write_body(expected_server_version=1),
    ).json()
    assert stale["outcome"] == "conflict"
    assert stale["item"] == changed["item"]

    deleted = client.post(
        "/ai/report-feedback/delete",
        headers=auth_headers,
        json={
            "feedback_id": FEEDBACK_ID,
            "report_id": REPORT_ID,
            "report_version": 1,
            "expected_server_version": 2,
        },
    ).json()
    assert deleted["outcome"] == "applied"
    assert deleted["item"]["server_version"] == 3
    assert deleted["item"]["deleted_at"] is not None
    repeated = client.post(
        "/ai/report-feedback/delete",
        headers=auth_headers,
        json={
            "feedback_id": FEEDBACK_ID,
            "report_id": REPORT_ID,
            "report_version": 1,
            "expected_server_version": 2,
        },
    ).json()
    assert repeated == deleted


def test_feedback_can_be_deleted_after_its_report_tombstone(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    _push_report(client, auth_headers, registered_device)
    client.post(
        "/ai/report-feedback/upsert",
        headers=auth_headers,
        json=_write_body(),
    )
    with client.app.state.database.session_factory() as session:
        report = session.scalar(
            select(SyncItem).where(
                SyncItem.table_name == "ai_reports",
                SyncItem.record_id == REPORT_ID,
            )
        )
        assert report is not None
        report.deleted_at = 1_786_496_400_300
        session.commit()

    deleted = client.post(
        "/ai/report-feedback/delete",
        headers=auth_headers,
        json={
            "feedback_id": FEEDBACK_ID,
            "report_id": REPORT_ID,
            "report_version": 1,
            "expected_server_version": 1,
        },
    )
    assert deleted.status_code == 200
    assert deleted.json()["item"]["deleted_at"] is not None


def test_list_is_account_scoped_and_excludes_sensitive_report_data(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    _push_report(client, auth_headers, registered_device)
    client.post(
        "/ai/report-feedback/upsert",
        headers=auth_headers,
        json=_write_body(),
    )
    listed = client.get("/ai/report-feedback", headers=auth_headers)
    assert listed.status_code == 200
    assert len(listed.json()["items"]) == 1
    serialized = json.dumps(listed.json(), ensure_ascii=False).lower()
    for forbidden in (
        "private report body",
        "prompt_text",
        "authorization",
        "api_key",
        "secret",
        "cloud_user_id",
    ):
        assert forbidden not in serialized

    other_login = client.post(
        "/auth/dev-login",
        json={"dev_user_key": "feedback-other-user"},
    )
    other_headers = {
        "Authorization": f"Bearer {other_login.json()['access_token']}"
    }
    assert client.get(
        "/ai/report-feedback", headers=other_headers
    ).json() == {"items": []}
    rejected = client.post(
        "/ai/report-feedback/upsert",
        headers=other_headers,
        json=_write_body(),
    )
    assert rejected.status_code == 409


def test_feedback_audit_is_read_only_aggregate_without_user_or_content(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    _push_report(client, auth_headers, registered_device)
    client.post(
        "/ai/report-feedback/upsert",
        headers=auth_headers,
        json=_write_body(
            helpfulness="not_helpful",
            reason_codes=["too_generic"],
        ),
    )
    session_factory = client.app.state.database.session_factory
    with session_factory() as session:
        stored = session.scalar(select(AiReportFeedback))
        assert stored is not None
        result = feedback_audit(
            session,
            days=30,
            now=stored.updated_at + 1,
        )

    assert result["read_only"] is True
    assert result["active_sample_size"] == 1
    assert result["groups"][0]["prompt_id"] == "weekly_report"
    assert result["groups"][0]["prompt_version"] == "weekly-report-v1"
    assert result["groups"][0]["helpful_rate"] == 0.0
    assert result["groups"][0]["reason_counts"] == {"too_generic": 1}
    serialized = json.dumps(result).lower()
    assert "cloud_user_id" not in serialized
    assert "private report body" not in serialized
    assert "prompt_text" not in serialized

    with session_factory() as session:
        expired = feedback_audit(
            session,
            days=30,
            now=stored.updated_at + 31 * 24 * 60 * 60 * 1000,
        )
    assert expired["active_sample_size"] == 0
    assert expired["groups"] == []


def test_feedback_audit_cli_defaults_to_30_days_and_is_privacy_safe(
    tmp_path: object,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    from app.database import Database

    database_file = tmp_path / "feedback-audit.sqlite"
    database_url = f"sqlite:///{database_file.as_posix()}"
    database = Database(database_url)
    database.create_schema()
    database.engine.dispose()
    monkeypatch.setenv("REBIRTH_DATABASE_URL", database_url)
    monkeypatch.setenv("REBIRTH_AI_PROVIDER", "disabled")
    monkeypatch.setattr(sys, "argv", ["rebirth_ai", "feedback-audit"])

    assert operations_main() == 0
    result = json.loads(capsys.readouterr().out)
    assert result["window_days"] == 30
    assert result["read_only"] is True
    assert "cloud_user_id" not in json.dumps(result).lower()


def test_feedback_audit_excludes_deleted_rows_and_never_mutates_them(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    _push_report(client, auth_headers, registered_device)
    client.post(
        "/ai/report-feedback/upsert",
        headers=auth_headers,
        json=_write_body(),
    )
    deleted = client.post(
        "/ai/report-feedback/delete",
        headers=auth_headers,
        json={
            "feedback_id": FEEDBACK_ID,
            "report_id": REPORT_ID,
            "report_version": 1,
            "expected_server_version": 1,
        },
    ).json()["item"]

    session_factory = client.app.state.database.session_factory
    with session_factory() as session:
        before = session.scalar(select(AiReportFeedback))
        assert before is not None
        result = feedback_audit(session, days=30, now=before.updated_at + 1)
        after = session.scalar(select(AiReportFeedback))
        assert after is not None
        assert (after.server_version, after.updated_at, after.deleted_at) == (
            before.server_version,
            before.updated_at,
            before.deleted_at,
        )

    assert result["active_sample_size"] == 0
    assert result["deleted_count"] == 1
    assert result["groups"] == []
    assert deleted["deleted_at"] is not None

    with session_factory() as session:
        with pytest.raises(ValueError, match="days must be positive"):
            feedback_audit(session, days=0)
