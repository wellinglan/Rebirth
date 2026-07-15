from __future__ import annotations

from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient

from app.main import create_app


@pytest.fixture
def client(tmp_path: object) -> Generator[TestClient, None, None]:
    database_file = tmp_path / "rebirth_test.sqlite"
    app = create_app(
        database_url=f"sqlite:///{database_file.as_posix()}",
        environment="development",
        jwt_secret="rebirth-test-only-jwt-secret-at-least-32-bytes",
    )
    with TestClient(app) as test_client:
        yield test_client
    app.state.database.engine.dispose()


@pytest.fixture
def auth_headers(client: TestClient) -> dict[str, str]:
    response = client.post(
        "/auth/dev-login",
        json={"dev_user_key": "pytest-user"},
    )
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


@pytest.fixture
def registered_device(
    client: TestClient,
    auth_headers: dict[str, str],
) -> str:
    response = client.post(
        "/devices/register",
        headers=auth_headers,
        json={
            "local_installation_id": "pytest-installation",
            "platform": "windows",
            "device_name": "Pytest PC",
            "app_version": "1.0.0+1",
        },
    )
    assert response.status_code == 200
    return response.json()["device_id"]
