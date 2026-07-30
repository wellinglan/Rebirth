from __future__ import annotations

import time
import uuid
from collections.abc import Generator

import jwt
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.main import create_app
from app.models import (
    AuthCredential,
    AuthIdentity,
    AuthLoginThrottle,
    AuthRefreshToken,
    AuthSession,
    CloudUser,
)


def test_register_creates_password_identity_credential_and_session(
    client: TestClient,
) -> None:
    response = _register(client, username="Alpha.User")

    assert response.status_code == 200
    body = response.json()
    assert body["identity_provider"] == "password_username"
    assert body["session_id"]
    assert body["refresh_token"].count(".") == 1
    claims = jwt.decode(
        body["access_token"],
        options={"verify_signature": False},
    )
    assert {
        "sub",
        "sid",
        "aid",
        "type",
        "jti",
        "iat",
        "exp",
        "iss",
        "aud",
    } <= claims.keys()
    database = client.app.state.database
    with database.session_factory() as session:
        identity = session.scalar(
            select(AuthIdentity).where(
                AuthIdentity.provider == "password_username"
            )
        )
        credential = session.scalar(select(AuthCredential))
        auth_session = session.scalar(select(AuthSession))
        refresh = session.scalar(select(AuthRefreshToken))
        assert identity is not None
        assert identity.provider_subject == "alpha.user"
        assert credential is not None
        assert credential.password_algorithm == "argon2id"
        assert "correct horse" not in credential.password_hash
        assert auth_session is not None
        assert refresh is not None
        assert refresh.token_hash not in body["refresh_token"]


def test_username_is_case_insensitive_and_duplicate_is_rejected(
    client: TestClient,
) -> None:
    assert _register(client, username="Case.Name").status_code == 200
    duplicate = _register(client, username="case.name")

    assert duplicate.status_code == 409
    assert duplicate.json()["detail"]["code"] == "login_identifier_unavailable"


def test_username_may_start_with_a_digit(client: TestClient) -> None:
    response = _register(client, username="1alpha.user")

    assert response.status_code == 200
    assert response.json()["identity_provider"] == "password_username"


@pytest.mark.parametrize(
    "password",
    [
        "short",
        "valid-length\x00password",
        "valid-length\npassword",
    ],
)
def test_password_policy_rejects_invalid_values(
    client: TestClient,
    password: str,
) -> None:
    response = _register(client, username="policy-user", password=password)

    assert response.status_code == 422
    assert response.json()["detail"]["code"] in {
        "invalid_request",
        "password_policy_violation",
    }


def test_password_is_not_trimmed(client: TestClient) -> None:
    password = "  correct horse battery staple  "
    assert (
        _register(
            client,
            username="space-user",
            password=password,
        ).status_code
        == 200
    )
    exact = client.post(
        "/auth/login",
        json={"username": "space-user", "password": password},
    )
    trimmed = client.post(
        "/auth/login",
        json={"username": "space-user", "password": password.strip()},
    )

    assert exact.status_code == 200
    assert trimmed.status_code == 401
    assert trimmed.json()["detail"]["code"] == "invalid_credentials"


def test_unknown_user_and_wrong_password_share_error(
    client: TestClient,
) -> None:
    _register(client, username="known-user")
    unknown = client.post(
        "/auth/login",
        json={"username": "other-user", "password": "wrong password value"},
    )
    wrong = client.post(
        "/auth/login",
        json={"username": "known-user", "password": "wrong password value"},
    )

    assert unknown.status_code == wrong.status_code == 401
    assert unknown.json()["detail"] == wrong.json()["detail"]


def test_refresh_rotates_and_reuse_revokes_only_that_session(
    client: TestClient,
) -> None:
    original = _register(client, username="rotation-user").json()
    second_session = client.post(
        "/auth/login",
        json={
            "username": "rotation-user",
            "password": _PASSWORD,
        },
    ).json()
    rotated = client.post(
        "/auth/refresh",
        json={"refresh_token": original["refresh_token"]},
    )
    assert rotated.status_code == 200
    assert rotated.json()["refresh_token"] != original["refresh_token"]

    reused = client.post(
        "/auth/refresh",
        json={"refresh_token": original["refresh_token"]},
    )
    assert reused.status_code == 401
    assert reused.json()["detail"]["code"] == "refresh_token_reused"

    revoked = client.get(
        "/auth/session",
        headers=_bearer(rotated.json()["access_token"]),
    )
    other = client.get(
        "/auth/session",
        headers=_bearer(second_session["access_token"]),
    )
    assert revoked.status_code == 401
    assert revoked.json()["detail"]["code"] == "session_revoked"
    assert other.status_code == 200


def test_logout_is_idempotent_and_revokes_current_session(
    client: TestClient,
) -> None:
    tokens = _register(client, username="logout-user").json()
    first = client.post(
        "/auth/logout",
        headers=_bearer(tokens["access_token"]),
        json={"refresh_token": tokens["refresh_token"]},
    )
    second = client.post(
        "/auth/logout",
        json={"refresh_token": tokens["refresh_token"]},
    )
    after = client.get(
        "/auth/session",
        headers=_bearer(tokens["access_token"]),
    )

    assert first.status_code == second.status_code == 200
    assert after.status_code == 401
    assert after.json()["detail"]["code"] == "session_revoked"


def test_logout_revokes_by_refresh_when_access_token_is_expired(
    client: TestClient,
) -> None:
    tokens = _register(client, username="expired-logout-user").json()
    claims = jwt.decode(tokens["access_token"], options={"verify_signature": False})
    claims["iat"] = 1
    claims["exp"] = 2
    expired_access = jwt.encode(
        claims,
        client.app.state.settings.jwt_secret,
        algorithm="HS256",
    )

    logout = client.post(
        "/auth/logout",
        headers=_bearer(expired_access),
        json={"refresh_token": tokens["refresh_token"]},
    )
    after = client.get(
        "/auth/session",
        headers=_bearer(tokens["access_token"]),
    )

    assert logout.status_code == 200
    assert after.status_code == 401
    assert after.json()["detail"]["code"] == "session_revoked"


def test_dev_identity_uses_hmac_and_password_attach_keeps_cloud_user(
    client: TestClient,
) -> None:
    key = "private-development-key"
    login = client.post("/auth/dev-login", json={"dev_user_key": key})
    assert login.status_code == 200
    body = login.json()
    attach = client.post(
        "/auth/identities/password/attach",
        headers=_bearer(body["access_token"]),
        json={
            "dev_user_key": key,
            "username": "attached-user",
            "password": _PASSWORD,
        },
    )
    password_login = client.post(
        "/auth/login",
        json={"username": "attached-user", "password": _PASSWORD},
    )

    assert attach.status_code == 200
    assert password_login.status_code == 200
    assert password_login.json()["user"]["id"] == body["user"]["id"]
    with client.app.state.database.session_factory() as session:
        dev_identity = session.scalar(
            select(AuthIdentity).where(AuthIdentity.provider == "dev")
        )
        assert dev_identity is not None
        assert dev_identity.provider_subject != key
        assert len(dev_identity.provider_subject) == 64
        user = session.get_one(CloudUser, body["user"]["id"])
        assert user.display_name == "Alpha User"


def test_legacy_raw_dev_identity_is_migrated_without_changing_user(
    client: TestClient,
) -> None:
    key = "legacy-raw-key"
    user_id = str(uuid.uuid4())
    now = time.time_ns() // 1_000_000
    with client.app.state.database.session_factory() as session:
        session.add(
            CloudUser(
                id=user_id,
                display_name=f"Dev {key}",
                created_at=now,
                updated_at=now,
                deleted_at=None,
            )
        )
        session.flush()
        session.add(
            AuthIdentity(
                id=str(uuid.uuid4()),
                user_id=user_id,
                provider="dev",
                provider_subject=key,
                provider_union_id=None,
                created_at=now,
                updated_at=now,
            )
        )
        session.commit()

    response = client.post("/auth/dev-login", json={"dev_user_key": key})

    assert response.status_code == 200
    assert response.json()["user"]["id"] == user_id
    with client.app.state.database.session_factory() as session:
        identity = session.scalar(
            select(AuthIdentity).where(AuthIdentity.user_id == user_id)
        )
        user = session.get_one(CloudUser, user_id)
        assert identity is not None
        assert identity.provider_subject != key
        assert user.display_name == "Alpha User"


def test_login_rate_limit_uses_hashed_bucket(client: TestClient) -> None:
    for _ in range(5):
        response = client.post(
            "/auth/login",
            json={
                "username": "unknown-rate-user",
                "password": "wrong password value",
            },
        )
        assert response.status_code == 401
    blocked = client.post(
        "/auth/login",
        json={
            "username": "unknown-rate-user",
            "password": "wrong password value",
        },
    )

    assert blocked.status_code == 429
    assert blocked.json()["detail"]["code"] == "authentication_rate_limited"
    with client.app.state.database.session_factory() as session:
        row = session.execute(select(AuthLoginThrottle)).scalar_one()
        assert row.bucket_key != "unknown-rate-user"
        assert len(row.bucket_key) == 64


def test_legacy_refresh_migrates_once_before_deadline(
    legacy_client: TestClient,
) -> None:
    current = legacy_client.post(
        "/auth/dev-login",
        json={"dev_user_key": "legacy-token-user"},
    ).json()
    now = int(time.time())
    legacy_refresh = jwt.encode(
        {
            "sub": current["user"]["id"],
            "type": "refresh",
            "iat": now,
            "exp": now + 3600,
        },
        _JWT_SECRET,
        algorithm="HS256",
    )
    migrated = legacy_client.post(
        "/auth/refresh",
        json={"refresh_token": legacy_refresh},
    )
    reused = legacy_client.post(
        "/auth/refresh",
        json={"refresh_token": legacy_refresh},
    )

    assert migrated.status_code == 200
    assert migrated.json()["refresh_token"].count(".") == 1
    assert reused.status_code == 401
    assert reused.json()["detail"]["code"] == "refresh_token_reused"


@pytest.fixture
def legacy_client(tmp_path: object) -> Generator[TestClient, None, None]:
    database_file = tmp_path / "rebirth_legacy_auth.sqlite"
    app = create_app(
        database_url=f"sqlite:///{database_file.as_posix()}",
        environment="development",
        jwt_secret=_JWT_SECRET,
        auth_refresh_token_hmac_key=_REFRESH_KEY,
        auth_dev_identity_hmac_key=_DEV_KEY,
        auth_rate_limit_hmac_key=_RATE_KEY,
        auth_legacy_token_migration_enabled=True,
        auth_legacy_token_migration_deadline="2099-01-01T00:00:00Z",
    )
    with TestClient(app) as test_client:
        yield test_client
    app.state.database.engine.dispose()


def _register(
    client: TestClient,
    *,
    username: str,
    password: str = "correct horse battery staple",
) -> object:
    return client.post(
        "/auth/register",
        json={"username": username, "password": password},
    )


def _bearer(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


_PASSWORD = "correct horse battery staple"
_JWT_SECRET = "auth-protocol-test-jwt-secret-material-123456"
_REFRESH_KEY = "auth-protocol-test-refresh-hmac-material-123456"
_DEV_KEY = "auth-protocol-test-dev-hmac-material-123456789"
_RATE_KEY = "auth-protocol-test-rate-hmac-material-12345678"
