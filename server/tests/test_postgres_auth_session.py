from __future__ import annotations

import os
import uuid
from concurrent.futures import ThreadPoolExecutor

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, inspect

from app.main import create_app


pytestmark = [
    pytest.mark.postgres,
    pytest.mark.skipif(
        not os.getenv("REBIRTH_POSTGRES_TEST_URL"),
        reason="REBIRTH_POSTGRES_TEST_URL is not configured",
    ),
]

AUTH_TABLES = {
    "auth_credentials",
    "auth_sessions",
    "auth_refresh_tokens",
    "auth_login_throttles",
    "legacy_refresh_migrations",
    "oauth_transactions",
}


def test_postgres_auth_revision_downgrade_and_upgrade() -> None:
    database_url = os.environ["REBIRTH_POSTGRES_TEST_URL"]
    config = Config("alembic.ini")
    command.upgrade(config, "head")
    engine = create_engine(database_url)
    try:
        assert AUTH_TABLES.issubset(inspect(engine).get_table_names())
        command.downgrade(config, "20260717_0002")
        assert AUTH_TABLES.isdisjoint(inspect(engine).get_table_names())
        command.upgrade(config, "head")
        assert AUTH_TABLES.issubset(inspect(engine).get_table_names())
    finally:
        engine.dispose()


def test_postgres_concurrent_refresh_has_one_winner_and_revokes_family() -> None:
    database_url = os.environ["REBIRTH_POSTGRES_TEST_URL"]
    command.upgrade(Config("alembic.ini"), "head")
    app = create_app(
        database_url=database_url,
        environment="test",
        jwt_secret="postgres-auth-jwt-secret-at-least-32-bytes",
        auth_refresh_token_hmac_key=(
            "postgres-auth-refresh-secret-at-least-32-bytes"
        ),
        auth_dev_identity_hmac_key=(
            "postgres-auth-dev-secret-at-least-32-bytes"
        ),
        auth_rate_limit_hmac_key=(
            "postgres-auth-rate-limit-secret-at-least-32-bytes"
        ),
    )
    with TestClient(app) as client:
        registered = client.post(
            "/auth/register",
            json={
                "username": f"auth_{uuid.uuid4().hex}",
                "password": "correct horse battery staple",
                "platform": "windows",
            },
        )
        assert registered.status_code == 200
        refresh_token = registered.json()["refresh_token"]

        def refresh() -> tuple[int, dict[str, object]]:
            response = client.post(
                "/auth/refresh",
                json={"refresh_token": refresh_token, "platform": "windows"},
            )
            return response.status_code, response.json()

        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(lambda _: refresh(), range(2)))

        assert sorted(status for status, _ in results) == [200, 401]
        rejection = next(body for status, body in results if status == 401)
        assert rejection["detail"]["code"] == "refresh_token_reused"
        winner = next(body for status, body in results if status == 200)
        session = client.get(
            "/auth/session",
            headers={"Authorization": f"Bearer {winner['access_token']}"},
        )
        assert session.status_code == 401
        assert session.json()["detail"]["code"] == "session_revoked"

    app.state.database.engine.dispose()
