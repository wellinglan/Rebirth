from __future__ import annotations

import json
import multiprocessing
import os
import uuid
from typing import Any

import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import select

from app.ai.feedback import AiReportFeedbackService
from app.ai.schemas import AiReportFeedbackWriteRequest
from app.database import Database
from app.models import AiReportFeedback, CloudUser, SyncItem


pytestmark = [
    pytest.mark.postgres,
    pytest.mark.skipif(
        not os.getenv("REBIRTH_POSTGRES_TEST_URL"),
        reason="REBIRTH_POSTGRES_TEST_URL is not configured",
    ),
]


def _worker(
    database_url: str,
    user_id: str,
    report_id: str,
    feedback_id: str,
    reason: str,
    barrier: Any,
    queue: Any,
) -> None:
    database = Database(database_url)
    try:
        request = AiReportFeedbackWriteRequest.model_validate(
            {
                "feedback_id": feedback_id,
                "report_id": report_id,
                "report_version": 1,
                "report_type": "weekly_report",
                "helpfulness": "not_helpful",
                "reason_codes": [reason],
                "prompt_id": "weekly_report",
                "prompt_version": "weekly-report-v1",
                "expected_server_version": 1,
            }
        )
        barrier.wait(timeout=20)
        with database.session_factory() as session:
            result = AiReportFeedbackService().write(
                session,
                user_id=user_id,
                request=request,
            )
            queue.put((result.outcome, result.item.server_version))
    finally:
        database.engine.dispose()


def test_concurrent_feedback_update_has_one_winner_and_one_conflict() -> None:
    database_url = os.environ["REBIRTH_POSTGRES_TEST_URL"]
    os.environ["REBIRTH_DATABASE_URL"] = database_url
    command.upgrade(Config("alembic.ini"), "head")
    user_id = str(uuid.uuid4())
    report_id = str(uuid.uuid4())
    feedback_id = str(uuid.uuid4())
    database = Database(database_url)
    try:
        with database.session_factory() as session:
            session.add(
                CloudUser(
                    id=user_id,
                    display_name="Feedback OCC",
                    created_at=1,
                    updated_at=1,
                    deleted_at=None,
                )
            )
            session.add(
                SyncItem(
                    id=str(uuid.uuid4()),
                    user_id=user_id,
                    table_name="ai_reports",
                    record_id=report_id,
                    payload_json=json.dumps(
                        {
                            "report_type": "weekly_report",
                            "versions": [
                                {
                                    "version": 1,
                                    "status": "completed",
                                    "content": "private",
                                }
                            ],
                        }
                    ),
                    server_version=1,
                    client_updated_at=1,
                    server_updated_at=1,
                    deleted_at=None,
                    origin_device_id=str(uuid.uuid4()),
                )
            )
            session.commit()
            created = AiReportFeedbackService(clock=lambda: 10).write(
                session,
                user_id=user_id,
                request=AiReportFeedbackWriteRequest.model_validate(
                    {
                        "feedback_id": feedback_id,
                        "report_id": report_id,
                        "report_version": 1,
                        "report_type": "weekly_report",
                        "helpfulness": "helpful",
                        "reason_codes": [],
                        "prompt_id": "weekly_report",
                        "prompt_version": "weekly-report-v1",
                        "expected_server_version": None,
                    }
                ),
            )
            assert created.item.server_version == 1

        context = multiprocessing.get_context("spawn")
        barrier = context.Barrier(2)
        queue = context.Queue()
        processes = [
            context.Process(
                target=_worker,
                args=(
                    database_url,
                    user_id,
                    report_id,
                    feedback_id,
                    reason,
                    barrier,
                    queue,
                ),
            )
            for reason in ("not_actionable", "too_generic")
        ]
        for process in processes:
            process.start()
        results = [queue.get(timeout=30) for _ in processes]
        for process in processes:
            process.join(timeout=30)
            assert process.exitcode == 0

        assert sorted(outcome for outcome, _ in results) == ["applied", "conflict"]
        assert {version for _, version in results} == {2}
        with database.session_factory() as session:
            row = session.scalar(
                select(AiReportFeedback).where(
                    AiReportFeedback.cloud_user_id == user_id,
                    AiReportFeedback.report_record_id == report_id,
                )
            )
            assert row is not None
            assert row.server_version == 2
    finally:
        database.engine.dispose()
