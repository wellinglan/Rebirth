from __future__ import annotations

import multiprocessing
import os
import uuid
from copy import deepcopy
from dataclasses import replace
from typing import Any

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import func, select, text

from app.ai.canonical import input_hash
from app.ai.ledger import AiRequestLedger
from app.ai.operations import audit_usage, check_ledger_consistency
from app.ai.providers import FakeAiProvider
from app.ai.schemas import (
    AiDailyGenerateRequest,
    AiWeeklyGenerateRequest,
    AiWeeklyPayload,
)
from app.ai.service import AiGenerationService
from app.ai.errors import UsageLimitReachedError
from app.ai.usage import AiUsageGuard
from app.config import load_settings
from app.database import Database
from app.main import create_app
from app.models import AiGenerationRequest, AiUsageRecord, CloudUser
from tests.test_ai_gateway import request_body
from tests.test_ai_daily_insight import daily_request_body


pytestmark = [
    pytest.mark.postgres,
    pytest.mark.skipif(
        not os.getenv("REBIRTH_POSTGRES_TEST_URL"),
        reason="REBIRTH_POSTGRES_TEST_URL is not configured",
    ),
]

_PROCESS_COUNT = 4
_NOW = 1_784_000_000_000


def _database_url() -> str:
    return os.environ["REBIRTH_POSTGRES_TEST_URL"]


def _upgrade() -> None:
    os.environ["REBIRTH_DATABASE_URL"] = _database_url()
    command.upgrade(Config("alembic.ini"), "head")


def _seed_users(*user_ids: str) -> None:
    database = Database(_database_url())
    try:
        with database.session_factory() as session:
            for user_id in user_ids:
                if session.get(CloudUser, user_id) is None:
                    session.add(
                        CloudUser(
                            id=user_id,
                            display_name="PostgreSQL Test",
                            created_at=_NOW,
                            updated_at=_NOW,
                            deleted_at=None,
                        )
                    )
            session.commit()
    finally:
        database.engine.dispose()


def _claim_worker(
    database_url: str,
    user_id: str,
    body: dict[str, Any],
    barrier: Any,
    queue: Any,
) -> None:
    settings = load_settings(
        database_url=database_url,
        environment="test",
        jwt_secret="postgres-multiprocess-test-secret",
    )
    database = Database(database_url)
    try:
        request = AiWeeklyGenerateRequest.model_validate(body)
        barrier.wait(timeout=20)
        with database.session_factory() as session:
            claim = AiRequestLedger(settings).claim(
                session, user_id=user_id, request=request, now=_NOW
            )
            queue.put((claim.owns_provider_call, claim.row.status))
    finally:
        database.engine.dispose()


def _expire_worker(
    database_url: str,
    user_id: str,
    request_id: str,
    barrier: Any,
    queue: Any,
) -> None:
    settings = load_settings(
        database_url=database_url,
        environment="test",
        jwt_secret="postgres-multiprocess-test-secret",
    )
    database = Database(database_url)
    try:
        with database.session_factory() as session:
            row = session.scalar(
                select(AiGenerationRequest).where(
                    AiGenerationRequest.user_id == user_id,
                    AiGenerationRequest.request_id == request_id,
                )
            )
            barrier.wait(timeout=20)
            changed = AiRequestLedger(settings).expire_stale_processing(
                session, row, now=_NOW
            )
            queue.put((changed, row.status))
    finally:
        database.engine.dispose()


def _daily_claim_worker(
    database_url: str,
    user_id: str,
    body: dict[str, Any],
    barrier: Any,
    queue: Any,
) -> None:
    settings = load_settings(
        database_url=database_url,
        environment="test",
        jwt_secret="postgres-multiprocess-test-secret",
    )
    database = Database(database_url)
    try:
        request = AiDailyGenerateRequest.model_validate(body)
        barrier.wait(timeout=20)
        with database.session_factory() as session:
            claim = AiRequestLedger(settings).claim(
                session, user_id=user_id, request=request, now=_NOW
            )
            queue.put((claim.owns_provider_call, claim.row.status))
    finally:
        database.engine.dispose()


def _run_processes(target: Any, arguments: list[tuple[Any, ...]]) -> list[Any]:
    context = multiprocessing.get_context("spawn")
    barrier = context.Barrier(len(arguments))
    queue = context.Queue()
    processes = [
        context.Process(target=target, args=(*args, barrier, queue))
        for args in arguments
    ]
    for process in processes:
        process.start()
    results = [queue.get(timeout=30) for _ in processes]
    for process in processes:
        process.join(timeout=30)
        assert process.exitcode == 0
    return results


def _usage_reservation_worker(
    database_url: str,
    user_id: str,
    request_id: str,
    barrier: Any,
    queue: Any,
) -> None:
    settings = replace(
        load_settings(
            database_url=database_url,
            environment="test",
            jwt_secret="postgres-multiprocess-test-secret",
        ),
        ai_daily_user_limit=100,
        ai_daily_global_limit=100,
        ai_max_concurrent_requests=5,
    )
    database = Database(database_url)
    try:
        barrier.wait(timeout=20)
        with database.session_factory() as session:
            try:
                AiUsageGuard(settings).reserve(
                    session,
                    user_id=user_id,
                    request_id=request_id,
                    provider="fake",
                    model="deterministic-test-provider",
                    request_type="weekly_report",
                    now=_NOW,
                )
                queue.put("reserved")
            except UsageLimitReachedError:
                queue.put("limited")
    finally:
        database.engine.dispose()


def _operations_read_worker(
    database_url: str,
    barrier: Any,
    queue: Any,
) -> None:
    database = Database(database_url)
    try:
        barrier.wait(timeout=20)
        with database.session_factory() as session:
            audit = audit_usage(session, days=7, now=_NOW)
            consistency = check_ledger_consistency(session, days=7, now=_NOW)
            queue.put(
                (
                    audit["totals"],
                    consistency["generation_count"],
                    consistency["usage_count"],
                    consistency["status"],
                )
            )
    finally:
        database.engine.dispose()


def test_postgres_version_and_migration() -> None:
    _upgrade()
    database = Database(_database_url())
    try:
        with database.engine.connect() as connection:
            version = connection.scalar(text("SHOW server_version"))
            assert version
            assert connection.scalar(
                text(
                    "SELECT count(*) FROM information_schema.tables "
                    "WHERE table_name='ai_generation_requests'"
                )
            ) == 1
    finally:
        database.engine.dispose()


def test_four_processes_have_exactly_one_claim_owner() -> None:
    _upgrade()
    user_id = str(uuid.uuid4())
    request_id = str(uuid.uuid4())
    _seed_users(user_id)
    body = request_body()
    body["request_id"] = request_id

    results = _run_processes(
        _claim_worker,
        [(_database_url(), user_id, body) for _ in range(_PROCESS_COUNT)],
    )
    assert sum(1 for owns, _ in results if owns) == 1
    assert {status for _, status in results} == {"processing"}

    database = Database(_database_url())
    try:
        with database.session_factory() as session:
            assert session.scalar(
                select(func.count())
                .select_from(AiGenerationRequest)
                .where(
                    AiGenerationRequest.user_id == user_id,
                    AiGenerationRequest.request_id == request_id,
                )
            ) == 1
    finally:
        database.engine.dispose()


def test_postgres_global_concurrency_reservation_is_atomic() -> None:
    _upgrade()
    user_id = str(uuid.uuid4())
    _seed_users(user_id)
    database = Database(_database_url())
    try:
        with database.session_factory() as session:
            session.query(AiUsageRecord).delete()
            session.commit()
    finally:
        database.engine.dispose()

    results = _run_processes(
        _usage_reservation_worker,
        [
            (_database_url(), user_id, str(uuid.uuid4()))
            for _ in range(8)
        ],
    )
    assert results.count("reserved") == 5
    assert results.count("limited") == 3

    database = Database(_database_url())
    try:
        settings = replace(
            load_settings(
                database_url=_database_url(),
                environment="test",
                jwt_secret="postgres-multiprocess-test-secret",
            ),
            ai_daily_user_limit=100,
            ai_daily_global_limit=100,
            ai_max_concurrent_requests=5,
        )
        with database.session_factory() as session:
            snapshot = AiUsageGuard(settings).snapshot(
                session,
                user_id=user_id,
                provider_enabled=True,
                now=_NOW,
            )
            assert snapshot.used == 5
            assert snapshot.remaining == 95
            assert snapshot.status == "limit_reached"
    finally:
        database.engine.dispose()


def test_daily_four_processes_have_exactly_one_claim_owner() -> None:
    _upgrade()
    user_id = str(uuid.uuid4())
    request_id = str(uuid.uuid4())
    _seed_users(user_id)
    body = daily_request_body()
    body["request_id"] = request_id

    results = _run_processes(
        _daily_claim_worker,
        [(_database_url(), user_id, body) for _ in range(_PROCESS_COUNT)],
    )
    assert sum(1 for owns, _ in results if owns) == 1
    assert {status for _, status in results} == {"processing"}

    database = Database(_database_url())
    try:
        with database.session_factory() as session:
            rows = session.scalars(
                select(AiGenerationRequest).where(
                    AiGenerationRequest.user_id == user_id,
                    AiGenerationRequest.request_id == request_id,
                )
            ).all()
            assert len(rows) == 1
            assert rows[0].report_type == "daily_insight"
    finally:
        database.engine.dispose()


def test_postgres_different_hash_returns_conflict() -> None:
    _upgrade()
    app = create_app(
        database_url=_database_url(),
        environment="development",
        jwt_secret="postgres-ai-test-jwt-secret-at-least-32-bytes",
    )
    provider = FakeAiProvider()
    app.state.ai_generation_service = AiGenerationService(app.state.settings, provider)
    try:
        with TestClient(app) as client:
            login = client.post(
                "/auth/dev-login",
                json={"dev_user_key": f"postgres-conflict-{uuid.uuid4()}"},
            )
            headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
            body = request_body()
            body["request_id"] = str(uuid.uuid4())
            assert client.post(
                "/ai/reports/weekly/generate", headers=headers, json=body
            ).status_code == 200

            conflicting = deepcopy(body)
            conflicting["payload"]["data"]["health_metrics"][0]["weight_kg"] = 88
            conflicting["input_hash"] = input_hash(
                AiWeeklyPayload.model_validate(conflicting["payload"])
            )
            response = client.post(
                "/ai/reports/weekly/generate",
                headers=headers,
                json=conflicting,
            )
            assert response.status_code == 409
            assert response.json()["detail"]["code"] == "idempotency_conflict"
            assert provider.calls == 1
    finally:
        app.state.database.engine.dispose()


def test_stale_lease_is_transitioned_once_across_four_processes() -> None:
    _upgrade()
    user_id = str(uuid.uuid4())
    request_id = str(uuid.uuid4())
    _seed_users(user_id)
    database = Database(_database_url())
    try:
        with database.session_factory() as session:
            session.add(
                AiGenerationRequest(
                    id=str(uuid.uuid4()),
                    user_id=user_id,
                    request_id=request_id,
                    input_hash="a" * 64,
                    report_type="weekly_report",
                    prompt_version="weekly-report-v1",
                    status="processing",
                    provider=None,
                    model=None,
                    output_schema_version=None,
                    report_content=None,
                    structured_output_json=None,
                    error_code=None,
                    created_at=_NOW - 1000,
                    updated_at=_NOW - 1000,
                    lease_expires_at=_NOW - 1,
                    result_expires_at=None,
                    dedupe_expires_at=_NOW + 86_400_000,
                    result_purged_at=None,
                )
            )
            session.commit()
    finally:
        database.engine.dispose()

    results = _run_processes(
        _expire_worker,
        [(_database_url(), user_id, request_id) for _ in range(_PROCESS_COUNT)],
    )
    assert sum(1 for changed, _ in results if changed) == 1
    assert {status for _, status in results} == {"outcome_unknown"}


def test_same_request_id_is_isolated_per_user_across_processes() -> None:
    _upgrade()
    users = (str(uuid.uuid4()), str(uuid.uuid4()))
    request_id = str(uuid.uuid4())
    _seed_users(*users)
    body = request_body()
    body["request_id"] = request_id
    arguments = [
        (_database_url(), users[index % 2], body) for index in range(_PROCESS_COUNT)
    ]
    results = _run_processes(_claim_worker, arguments)
    assert sum(1 for owns, _ in results if owns) == 2

    database = Database(_database_url())
    try:
        with database.session_factory() as session:
            assert session.scalar(
                select(func.count())
                .select_from(AiGenerationRequest)
                .where(AiGenerationRequest.request_id == request_id)
            ) == 2
    finally:
        database.engine.dispose()


def test_postgres_cleanup_dry_run_and_execution() -> None:
    _upgrade()
    user_id = str(uuid.uuid4())
    request_id = str(uuid.uuid4())
    _seed_users(user_id)
    database = Database(_database_url())
    settings = load_settings(
        database_url=_database_url(),
        environment="test",
        jwt_secret="postgres-cleanup-test-secret-at-least-32-bytes",
    )
    row_id = str(uuid.uuid4())
    try:
        with database.session_factory() as session:
            session.add(
                AiGenerationRequest(
                    id=row_id,
                    user_id=user_id,
                    request_id=request_id,
                    input_hash="b" * 64,
                    report_type="weekly_report",
                    prompt_version="weekly-report-v1",
                    status="completed",
                    provider="fake",
                    model="fake-model",
                    output_schema_version=1,
                    report_content="# temporary",
                    structured_output_json=(
                        '{"title":"t","summary":"s","observations":[],'
                        '"suggestions":[],"data_limitations":[]}'
                    ),
                    error_code=None,
                    created_at=_NOW - 1000,
                    updated_at=_NOW - 1000,
                    lease_expires_at=None,
                    result_expires_at=_NOW - 1,
                    dedupe_expires_at=_NOW + 86_400_000,
                    result_purged_at=None,
                )
            )
            session.commit()
            dry_run = AiRequestLedger(settings).cleanup(
                session, now=_NOW, dry_run=True
            )
            assert dry_run.result_candidate_count >= 1
            assert session.get(AiGenerationRequest, row_id).report_content is not None
            executed = AiRequestLedger(settings).cleanup(session, now=_NOW)
            assert executed.result_purge_count >= 1
            assert session.get(AiGenerationRequest, row_id).report_content is None
    finally:
        database.engine.dispose()


def test_postgres_operation_reads_are_consistent_across_processes() -> None:
    _upgrade()
    results = _run_processes(
        _operations_read_worker,
        [(_database_url(),) for _ in range(_PROCESS_COUNT)],
    )
    assert len(results) == _PROCESS_COUNT
    assert all(result == results[0] for result in results)
