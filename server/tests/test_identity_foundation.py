from __future__ import annotations

import uuid
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, inspect, select, text
from sqlalchemy.exc import IntegrityError

from app.models import AuthIdentity, CloudUser


def test_registration_creates_password_identity_with_usage_time(
    client: TestClient,
) -> None:
    response = _register(client, "identity-register")

    assert response.status_code == 200
    with client.app.state.database.session_factory() as session:
        identity = session.scalar(select(AuthIdentity))
        assert identity is not None
        assert identity.provider == "password_username"
        assert identity.last_used_at is not None
        assert identity.last_used_at >= identity.created_at


def test_authenticated_identity_list_is_safe_and_uses_public_provider(
    client: TestClient,
) -> None:
    token = _register(client, "identity-list").json()["access_token"]

    response = client.get("/auth/identities", headers=_bearer(token))

    assert response.status_code == 200
    identity = response.json()["identities"][0]
    assert identity["provider"] == "password"
    assert set(identity) == {"provider", "created_at", "last_used_at"}
    serialized = response.text.lower()
    for forbidden in (
        "provider_subject",
        "user_id",
        "password_hash",
        "access_token",
        "refresh_token",
    ):
        assert forbidden not in serialized


def test_identity_list_requires_authentication(client: TestClient) -> None:
    response = client.get("/auth/identities")

    assert response.status_code == 401


def test_provider_subject_cannot_belong_to_two_users(
    client: TestClient,
) -> None:
    database = client.app.state.database
    with database.session_factory() as session:
        first = _cloud_user("first")
        second = _cloud_user("second")
        session.add_all([first, second])
        session.flush()
        session.add(
            _identity(
                user_id=first.id,
                provider="future_provider",
                subject="external-subject",
            )
        )
        session.commit()
        session.add(
            _identity(
                user_id=second.id,
                provider="future_provider",
                subject="external-subject",
            )
        )
        with pytest.raises(IntegrityError):
            session.commit()


def test_login_keeps_cloud_user_and_updates_identity_last_used(
    client: TestClient,
) -> None:
    registered = _register(client, "stable-user").json()
    with client.app.state.database.session_factory() as session:
        identity = session.scalar(select(AuthIdentity))
        assert identity is not None
        identity.last_used_at = 1
        session.commit()

    logged_in = client.post(
        "/auth/login",
        json={"username": "stable-user", "password": _PASSWORD},
    )

    assert logged_in.status_code == 200
    assert logged_in.json()["user"]["id"] == registered["user"]["id"]
    with client.app.state.database.session_factory() as session:
        identity = session.scalar(select(AuthIdentity))
        assert identity is not None
        assert identity.last_used_at is not None
        assert identity.last_used_at > 1


def test_developer_and_password_identities_share_one_cloud_user(
    client: TestClient,
) -> None:
    developer = client.post(
        "/auth/dev-login",
        json={"dev_user_key": "multi-identity-user"},
    ).json()
    attached = client.post(
        "/auth/identities/password/attach",
        headers=_bearer(developer["access_token"]),
        json={
            "dev_user_key": "multi-identity-user",
            "username": "multi-identity",
            "password": _PASSWORD,
        },
    )
    assert attached.status_code == 200

    response = client.get(
        "/auth/identities",
        headers=_bearer(developer["access_token"]),
    )

    assert response.status_code == 200
    assert {item["provider"] for item in response.json()["identities"]} == {
        "developer",
        "password",
    }
    assert attached.json()["user"]["id"] == developer["user"]["id"]


def test_identity_migration_preserves_existing_data_and_downgrades(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    database_path = tmp_path / "identity_migration.sqlite"
    database_url = f"sqlite:///{database_path.as_posix()}"
    monkeypatch.setenv("REBIRTH_DATABASE_URL", database_url)
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", database_url)
    command.upgrade(config, "20260730_0003")
    engine = create_engine(database_url)
    with engine.begin() as connection:
        connection.execute(
            text(
                "INSERT INTO cloud_users "
                "(id, display_name, created_at, updated_at, deleted_at) "
                "VALUES ('existing-user', 'Existing', 10, 20, NULL)"
            )
        )
        connection.execute(
            text(
                "INSERT INTO auth_identities "
                "(id, user_id, provider, provider_subject, provider_union_id, "
                "created_at, updated_at) "
                "VALUES ('existing-identity', 'existing-user', "
                "'password_username', 'existing', NULL, 10, 20)"
            )
        )

    command.upgrade(config, "head")
    with engine.connect() as connection:
        row = connection.execute(
            text(
                "SELECT user_id, provider, provider_subject, last_used_at "
                "FROM auth_identities WHERE id='existing-identity'"
            )
        ).one()
        assert tuple(row) == (
            "existing-user",
            "password_username",
            "existing",
            20,
        )

    command.downgrade(config, "20260730_0003")
    assert "last_used_at" not in {
        column["name"]
        for column in inspect(engine).get_columns("auth_identities")
    }
    with engine.connect() as connection:
        assert connection.scalar(
            text(
                "SELECT provider_subject FROM auth_identities "
                "WHERE id='existing-identity'"
            )
        ) == "existing"
    engine.dispose()


def _register(client: TestClient, username: str) -> object:
    return client.post(
        "/auth/register",
        json={"username": username, "password": _PASSWORD},
    )


def _bearer(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _cloud_user(suffix: str) -> CloudUser:
    return CloudUser(
        id=str(uuid.uuid4()),
        display_name=suffix,
        created_at=1,
        updated_at=1,
        deleted_at=None,
    )


def _identity(
    *,
    user_id: str,
    provider: str,
    subject: str,
) -> AuthIdentity:
    return AuthIdentity(
        id=str(uuid.uuid4()),
        user_id=user_id,
        provider=provider,
        provider_subject=subject,
        provider_union_id=None,
        created_at=1,
        updated_at=1,
        last_used_at=None,
    )


_PASSWORD = "correct horse battery staple"
