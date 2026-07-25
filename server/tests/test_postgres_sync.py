from __future__ import annotations

import os
import uuid
from concurrent.futures import ThreadPoolExecutor

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient

from app.main import create_app


pytestmark = pytest.mark.postgres


@pytest.mark.skipif(
    not os.getenv("REBIRTH_POSTGRES_TEST_URL"),
    reason="REBIRTH_POSTGRES_TEST_URL is not configured",
)
def test_postgres_migration_and_concurrent_sync_versions_are_atomic(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    database_url = os.environ["REBIRTH_POSTGRES_TEST_URL"]
    monkeypatch.setenv("REBIRTH_DATABASE_URL", database_url)
    config = Config("alembic.ini")
    command.upgrade(config, "head")

    app = create_app(
        database_url=database_url,
        environment="development",
        jwt_secret="postgres-test-only-jwt-secret-at-least-32-bytes",
    )
    run_id = uuid.uuid4().hex
    credentials: list[tuple[dict[str, str], str]] = []
    with TestClient(app) as client:
        health = client.get("/health")
        assert health.status_code == 200
        for index in range(6):
            login = client.post(
                "/auth/dev-login",
                json={"dev_user_key": f"postgres-{run_id}-{index}"},
            )
            headers = {
                "Authorization": f"Bearer {login.json()['access_token']}"
            }
            registration = client.post(
                "/devices/register",
                headers=headers,
                json={
                    "local_installation_id": f"installation-{run_id}-{index}",
                    "platform": "windows",
                    "device_name": f"Postgres test {index}",
                    "app_version": "1.0.0+1",
                },
            )
            credentials.append((headers, registration.json()["device_id"]))

        def push(index: int) -> int:
            headers, device_id = credentials[index]
            response = client.post(
                "/sync/push",
                headers=headers,
                json={
                    "device_id": device_id,
                    "items": [
                        {
                            "table": "user_profiles",
                            "id": f"local-profile-{index}",
                            "payload": {
                                "display_name": f"User {index}",
                                "growth_focus": "Concurrency",
                                "timezone_id": "Etc/UTC",
                                "updated_at": 1_784_160_000_000 + index,
                            },
                            "updated_at": 1_784_160_000_000 + index,
                            "deleted_at": None,
                            "origin_device_id": f"origin-{run_id}-{index}",
                            "client_version": 0,
                        }
                    ],
                },
            )
            assert response.status_code == 200
            assert response.json()["accepted"][0]["id"] == "profile"
            return response.json()["accepted"][0]["server_version"]

        with ThreadPoolExecutor(max_workers=6) as executor:
            versions = list(executor.map(push, range(6)))

        assert len(set(versions)) == len(versions)
        assert all(left < right for left, right in zip(sorted(versions), sorted(versions)[1:]))

        headers, device_id = credentials[0]
        parent_id = str(uuid.uuid4())
        child_id = str(uuid.uuid4())
        plan_origin_id = str(uuid.uuid4())
        plan_batch = client.post(
            "/sync/push",
            headers=headers,
            json={
                "device_id": device_id,
                "items": [
                    {
                        "table": "goals",
                        "id": child_id,
                        "payload": {
                            "parent_goal_id": parent_id,
                            "title": "PostgreSQL child",
                            "description": None,
                            "goal_level": "month",
                            "status": "not_started",
                            "start_date": "2026-07-01",
                            "target_date": "2026-07-31",
                            "completed_at": None,
                            "archived_at": None,
                            "sort_order": 0,
                            "created_at": 1_784_160_100_000,
                        },
                        "updated_at": 1_784_160_100_000,
                        "deleted_at": None,
                        "origin_device_id": plan_origin_id,
                        "client_version": 0,
                    },
                    {
                        "table": "goals",
                        "id": parent_id,
                        "payload": {
                            "parent_goal_id": None,
                            "title": "PostgreSQL parent",
                            "description": None,
                            "goal_level": "year",
                            "status": "not_started",
                            "start_date": "2026-01-01",
                            "target_date": "2026-12-31",
                            "completed_at": None,
                            "archived_at": None,
                            "sort_order": 0,
                            "created_at": 1_784_160_100_000,
                        },
                        "updated_at": 1_784_160_100_000,
                        "deleted_at": None,
                        "origin_device_id": plan_origin_id,
                        "client_version": 0,
                    },
                ],
            },
        )
        assert plan_batch.status_code == 200
        assert plan_batch.json()["conflicts"] == []
        assert {item["id"] for item in plan_batch.json()["accepted"]} == {
            parent_id,
            child_id,
        }

    app.state.database.engine.dispose()
