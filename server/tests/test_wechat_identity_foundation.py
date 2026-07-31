from __future__ import annotations

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.identity import (
    IDENTITY_PROVIDERS,
    IdentityBindingError,
    IdentityCapability,
    VerifiedWechatIdentity,
    WECHAT_PROVIDER,
)
from app.models import AuthIdentity
from app.services.identity_service import IdentityService


def test_wechat_provider_metadata_declares_future_binding_capability() -> None:
    metadata = IDENTITY_PROVIDERS[WECHAT_PROVIDER]

    assert metadata.provider_id == "wechat"
    assert metadata.display_name == "WeChat"
    assert metadata.enabled is False
    assert metadata.capabilities == {
        IdentityCapability.LOGIN,
        IdentityCapability.BIND,
    }


def test_trusted_verified_wechat_openid_creates_identity(
    client: TestClient,
) -> None:
    registered = _register(client, "wechat-openid").json()

    identity = _bind(
        client,
        user_id=registered["user"]["id"],
        verified=VerifiedWechatIdentity(
            app_id="wx-app",
            open_id="openid-a",
        ),
    )

    assert identity.provider == "wechat"
    assert identity.provider_subject == "openid:wx-app:openid-a"
    assert identity.provider_union_id is None


def test_wechat_unionid_is_preferred_and_normalized(
    client: TestClient,
) -> None:
    registered = _register(client, "wechat-unionid").json()

    identity = _bind(
        client,
        user_id=registered["user"]["id"],
        verified=VerifiedWechatIdentity(
            app_id="wx-app",
            open_id="openid-a",
            union_id="  union-a  ",
        ),
    )

    assert identity.provider_subject == "unionid:union-a"
    assert identity.provider_union_id == "union-a"


def test_same_wechat_identity_cannot_be_bound_to_two_users(
    client: TestClient,
) -> None:
    first = _register(client, "wechat-first").json()["user"]["id"]
    second = _register(client, "wechat-second").json()["user"]["id"]
    verified = VerifiedWechatIdentity(
        app_id="wx-app",
        open_id="shared-openid",
    )
    _bind(client, user_id=first, verified=verified)

    try:
        _bind(client, user_id=second, verified=verified)
    except IdentityBindingError as error:
        assert error.code == "identity_binding_unavailable"
        assert error.status_code == 409
        assert "shared-openid" not in error.message
    else:
        raise AssertionError("Duplicate WeChat identity was accepted.")

    with client.app.state.database.session_factory() as session:
        identities = session.scalars(
            select(AuthIdentity).where(AuthIdentity.provider == "wechat")
        ).all()
        assert len(identities) == 1
        assert identities[0].user_id == first


def test_different_wechat_identities_can_belong_to_different_users(
    client: TestClient,
) -> None:
    first = _register(client, "wechat-different-a").json()["user"]["id"]
    second = _register(client, "wechat-different-b").json()["user"]["id"]

    first_identity = _bind(
        client,
        user_id=first,
        verified=VerifiedWechatIdentity("wx-app", "openid-a"),
    )
    second_identity = _bind(
        client,
        user_id=second,
        verified=VerifiedWechatIdentity("wx-app", "openid-b"),
    )

    assert first_identity.user_id == first
    assert second_identity.user_id == second


def test_identity_list_preserves_jwt_user_isolation_and_hides_subject(
    client: TestClient,
) -> None:
    first = _register(client, "wechat-jwt-a").json()
    second = _register(client, "wechat-jwt-b").json()
    _bind(
        client,
        user_id=first["user"]["id"],
        verified=VerifiedWechatIdentity("wx-app", "private-openid"),
    )

    first_response = client.get(
        "/auth/identities",
        headers=_bearer(first["access_token"]),
    )
    second_response = client.get(
        "/auth/identities",
        headers=_bearer(second["access_token"]),
    )

    assert first_response.status_code == 200
    assert {
        item["provider"] for item in first_response.json()["identities"]
    } == {"password", "wechat"}
    assert {
        item["provider"] for item in second_response.json()["identities"]
    } == {"password"}
    assert "private-openid" not in first_response.text
    assert "provider_subject" not in first_response.text
    assert "provider_union_id" not in first_response.text


def test_wechat_binding_start_requires_authentication(
    client: TestClient,
) -> None:
    response = client.post("/auth/identities/wechat/bind/start", json={})

    assert response.status_code == 401


def test_authenticated_binding_start_is_safe_and_does_not_trust_body(
    client: TestClient,
) -> None:
    registered = _register(client, "wechat-start").json()

    response = client.post(
        "/auth/identities/wechat/bind/start",
        headers=_bearer(registered["access_token"]),
        json={
            "cloud_user_id": "attacker-selected-user",
            "openid": "client-supplied-openid",
            "access_token": "client-supplied-token",
        },
    )

    assert response.status_code == 200
    assert response.json() == {
        "status": "provider_unavailable",
        "provider": "wechat",
        "requires_reauthentication": True,
        "message": "WeChat binding is not configured in this release.",
    }
    serialized = response.text.lower()
    for forbidden in (
        "attacker-selected-user",
        "client-supplied-openid",
        "client-supplied-token",
        "provider_subject",
        "unionid",
    ):
        assert forbidden not in serialized
    with client.app.state.database.session_factory() as session:
        assert (
            session.scalar(
                select(AuthIdentity).where(AuthIdentity.provider == "wechat")
            )
            is None
        )


def test_trusted_binding_requires_reauthentication(
    client: TestClient,
) -> None:
    user_id = _register(client, "wechat-reauth").json()["user"]["id"]

    with client.app.state.database.session_factory() as session:
        try:
            IdentityService(session).bind_verified_wechat_identity(
                user_id=user_id,
                verified_identity=VerifiedWechatIdentity(
                    "wx-app",
                    "openid-a",
                ),
                reauthentication_verified=False,
                now=100,
            )
        except IdentityBindingError as error:
            assert error.code == "reauthentication_required"
            assert error.status_code == 403
        else:
            raise AssertionError("Binding without reauthentication succeeded.")


def test_wechat_identity_storage_has_no_token_or_secret_columns() -> None:
    column_names = {column.name for column in AuthIdentity.__table__.columns}

    assert "access_token" not in column_names
    assert "refresh_token" not in column_names
    assert "token" not in column_names
    assert "secret" not in column_names


def _bind(
    client: TestClient,
    *,
    user_id: str,
    verified: VerifiedWechatIdentity,
) -> AuthIdentity:
    with client.app.state.database.session_factory() as session:
        return IdentityService(session).bind_verified_wechat_identity(
            user_id=user_id,
            verified_identity=verified,
            reauthentication_verified=True,
            now=100,
        )


def _register(client: TestClient, username: str) -> object:
    return client.post(
        "/auth/register",
        json={
            "username": username,
            "password": "correct horse battery staple",
        },
    )


def _bearer(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}
