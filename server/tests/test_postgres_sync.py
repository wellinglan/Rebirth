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

    app.state.database.engine.dispose()

