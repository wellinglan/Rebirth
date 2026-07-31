from __future__ import annotations

from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.identity import VerifiedWechatIdentity
from app.main import create_app
from app.models import AuthIdentity, OAuthTransaction, ReauthenticationProof
from app.oauth.providers import FakeWechatProvider


PASSWORD = "correct horse battery staple"


class _Clock:
    def __init__(self, value: int = 1_000_000) -> None:
        self.value = value

    def __call__(self) -> int:
        return self.value


@pytest.fixture
def step_up_client(tmp_path: Path):
    clock = _Clock()
    database_file = tmp_path / "rebirth_step_up.sqlite"
    app = create_app(
        database_url=f"sqlite:///{database_file.as_posix()}",
        environment="test",
        jwt_secret="step-up-test-jwt-secret-at-least-32-bytes",
        auth_refresh_token_hmac_key=(
            "step-up-refresh-test-secret-at-least-32-bytes"
        ),
        auth_dev_identity_hmac_key=(
            "step-up-developer-test-secret-at-least-32-bytes"
        ),
        auth_rate_limit_hmac_key=(
            "step-up-rate-limit-test-secret-at-least-32-bytes"
        ),
        wechat_app_id="step-up-test-app",
        wechat_app_secret="step-up-test-secret-not-real",
        wechat_provider_adapter=FakeWechatProvider(
            {
                "valid-a": VerifiedWechatIdentity(
                    "step-up-test-app",
                    "openid-a",
                    "union-a",
                ),
                "valid-b": VerifiedWechatIdentity(
                    "step-up-test-app",
                    "openid-b",
                    "union-b",
                ),
                "shared": VerifiedWechatIdentity(
                    "step-up-test-app",
                    "shared-openid",
                    "shared-union",
                ),
            }
        ),
        oauth_clock=clock,
        reauthentication_clock=clock,
    )
    with TestClient(app) as client:
        yield client, clock
    app.state.database.engine.dispose()


def test_correct_password_creates_hashed_short_lived_proof(
    step_up_client: object,
) -> None:
    client, clock = step_up_client
    account = _register(client, "step-up-password")

    response = _password_proof(client, account)

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "proof_created"
    assert body["purpose"] == "wechat_bind"
    assert body["method"] == "password"
    assert body["expires_at"] == clock.value + 5 * 60_000
    with client.app.state.database.session_factory() as session:
        proof = session.scalar(select(ReauthenticationProof))
        assert proof is not None
        assert proof.cloud_user_id == account["user"]["id"]
        assert proof.session_id == account["session_id"]
        assert proof.proof_hash != body["proof"]
        assert len(proof.proof_hash) == 64
        assert proof.status == "created"
        assert {column.name for column in proof.__table__.columns} == {
            "id",
            "cloud_user_id",
            "session_id",
            "purpose",
            "proof_hash",
            "created_at",
            "expires_at",
            "consumed_at",
            "status",
        }


def test_wrong_password_returns_one_generic_error(step_up_client: object) -> None:
    client, _ = step_up_client
    account = _register(client, "step-up-wrong")

    response = _password_proof(client, account, password="wrong password")

    assert response.status_code == 403
    assert response.json()["detail"] == {
        "code": "reauthentication_failed",
        "message": "The current login could not be verified.",
    }
    assert "step-up-wrong" not in response.text


def test_expired_and_reused_proofs_are_rejected(step_up_client: object) -> None:
    client, clock = step_up_client
    account = _register(client, "step-up-expiry")
    issued = _password_proof(client, account).json()
    clock.value = issued["expires_at"]

    expired = _start(client, account, issued["proof"])

    assert expired.status_code == 410
    assert expired.json()["detail"]["code"] == "reauthentication_proof_expired"

    clock.value -= 1
    fresh = _password_proof(client, account).json()
    first = _start(client, account, fresh["proof"])
    replay = _start(client, account, fresh["proof"])

    assert first.status_code == 200
    assert first.json()["status"] == "transaction_created"
    assert replay.status_code == 409
    assert replay.json()["detail"]["code"] == "reauthentication_proof_consumed"


def test_proof_is_bound_to_user_and_session(step_up_client: object) -> None:
    client, _ = step_up_client
    account_a = _register(client, "step-up-a")
    account_b = _register(client, "step-up-b")
    proof = _password_proof(client, account_a).json()["proof"]

    cross_user = _start(client, account_b, proof)
    second_session = _login(client, "step-up-a")
    cross_session = _start(client, second_session, proof)

    assert cross_user.status_code == 403
    assert cross_session.status_code == 403
    assert cross_user.json()["detail"]["code"] == "reauthentication_proof_invalid"
    assert cross_session.json()["detail"]["code"] == "reauthentication_proof_invalid"


def test_logout_invalidates_proof(step_up_client: object) -> None:
    client, _ = step_up_client
    account = _register(client, "step-up-logout")
    proof = _password_proof(client, account).json()["proof"]

    logout = client.post(
        "/auth/logout",
        headers=_headers(account),
        json={"refresh_token": account["refresh_token"]},
    )
    start = _start(client, account, proof)

    assert logout.status_code == 200
    assert start.status_code == 401


def test_developer_reauthentication_is_explicitly_test_only(
    step_up_client: object,
) -> None:
    client, _ = step_up_client
    login = client.post(
        "/auth/dev-login",
        json={"dev_user_key": "step-up-developer"},
    ).json()

    response = client.post(
        "/auth/reauthenticate/developer",
        headers=_headers(login),
        json={
            "dev_user_key": "step-up-developer",
            "purpose": "wechat_bind",
        },
    )

    assert response.status_code == 200
    assert response.json()["method"] == "developer"


def test_developer_reauthentication_is_unavailable_in_production(
    tmp_path: Path,
) -> None:
    database_file = tmp_path / "rebirth_step_up_production.sqlite"
    app = create_app(
        database_url=f"sqlite:///{database_file.as_posix()}",
        environment="production",
        jwt_secret="production-step-up-jwt-secret-at-least-32-bytes",
        auth_refresh_token_hmac_key=(
            "production-step-up-refresh-secret-at-least-32-bytes"
        ),
        auth_dev_identity_hmac_key=(
            "production-step-up-dev-secret-at-least-32-bytes"
        ),
        auth_rate_limit_hmac_key=(
            "production-step-up-rate-secret-at-least-32-bytes"
        ),
    )
    try:
        with TestClient(app) as client:
            account = _register(client, "production-step-up")
            response = client.post(
                "/auth/reauthenticate/developer",
                headers=_headers(account),
                json={
                    "dev_user_key": "not-a-production-credential",
                    "purpose": "wechat_bind",
                },
            )
            assert response.status_code == 404
    finally:
        app.state.database.engine.dispose()


def test_password_and_proof_are_not_logged_or_persisted_in_plaintext(
    step_up_client: object,
    caplog: pytest.LogCaptureFixture,
) -> None:
    client, _ = step_up_client
    account = _register(client, "step-up-private-material")

    with caplog.at_level("INFO"):
        issued = _password_proof(client, account).json()
        started = _start(client, account, issued["proof"])

    assert started.status_code == 200
    assert PASSWORD not in caplog.text
    assert issued["proof"] not in caplog.text
    with client.app.state.database.session_factory() as session:
        proof = session.scalar(select(ReauthenticationProof))
        assert proof is not None
        assert proof.proof_hash != issued["proof"]
        assert "password" not in {column.name for column in proof.__table__.columns}


def test_callback_contract_completes_once_and_hides_internal_errors(
    step_up_client: object,
) -> None:
    client, _ = step_up_client
    account = _register(client, "callback-once")
    transaction = _new_transaction(client, account)

    completed = _callback(client, account, transaction, "valid-a")
    replay = _callback(client, account, transaction, "valid-a")

    assert completed.status_code == 200
    assert completed.json()["status"] == "completed"
    assert replay.status_code == 409
    assert replay.json()["detail"]["code"] == "already_consumed"
    assert "sql" not in replay.text.lower()


def test_callback_rejects_cross_account_and_provider_failure(
    step_up_client: object,
) -> None:
    client, _ = step_up_client
    account_a = _register(client, "callback-a")
    account_b = _register(client, "callback-b")
    transaction = _new_transaction(client, account_a)

    cross_account = _callback(client, account_b, transaction, "valid-a")
    provider_failure = _callback(
        client,
        account_a,
        transaction,
        "invalid-code",
    )

    assert cross_account.status_code == 409
    assert cross_account.json()["detail"]["code"] == "invalid_transaction"
    assert provider_failure.status_code == 502
    assert provider_failure.json()["detail"]["code"] == "provider_error"


def test_binding_conflict_preserves_existing_identity(step_up_client: object) -> None:
    client, _ = step_up_client
    account_a = _register(client, "binding-owner-a")
    account_b = _register(client, "binding-owner-b")
    first = _new_transaction(client, account_a)
    second = _new_transaction(client, account_b)

    assert _callback(client, account_a, first, "shared").status_code == 200
    conflict = _callback(client, account_b, second, "shared")

    assert conflict.status_code == 409
    assert conflict.json()["detail"]["code"] == "binding_conflict"
    with client.app.state.database.session_factory() as session:
        identity = session.scalar(
            select(AuthIdentity).where(
                AuthIdentity.provider == "wechat",
                AuthIdentity.provider_subject == "unionid:shared-union",
            )
        )
        assert identity is not None
        assert identity.user_id == account_a["user"]["id"]


def test_start_and_callback_persist_only_safe_security_metadata(
    step_up_client: object,
) -> None:
    client, _ = step_up_client
    account = _register(client, "safe-metadata")
    transaction = _new_transaction(client, account)

    with client.app.state.database.session_factory() as session:
        record = session.get_one(
            OAuthTransaction,
            transaction["transaction_id"],
        )
        assert record.session_id == account["session_id"]
        assert record.purpose == "wechat_bind"
        columns = {column.name for column in record.__table__.columns}
        assert not columns & {
            "password",
            "proof",
            "authorization_code",
            "provider_token",
            "provider_secret",
        }


def _register(client: TestClient, username: str) -> dict[str, object]:
    response = client.post(
        "/auth/register",
        json={"username": username, "password": PASSWORD},
    )
    assert response.status_code == 200
    return response.json()


def _login(client: TestClient, username: str) -> dict[str, object]:
    response = client.post(
        "/auth/login",
        json={"username": username, "password": PASSWORD},
    )
    assert response.status_code == 200
    return response.json()


def _password_proof(
    client: TestClient,
    account: dict[str, object],
    *,
    password: str = PASSWORD,
):
    return client.post(
        "/auth/reauthenticate/password",
        headers=_headers(account),
        json={"password": password, "purpose": "wechat_bind"},
    )


def _start(
    client: TestClient,
    account: dict[str, object],
    proof: str,
):
    return client.post(
        "/auth/identities/wechat/bind/start",
        headers=_headers(account),
        json={"reauthentication_proof": proof},
    )


def _new_transaction(
    client: TestClient,
    account: dict[str, object],
) -> dict[str, object]:
    proof = _password_proof(client, account)
    assert proof.status_code == 200
    started = _start(client, account, proof.json()["proof"])
    assert started.status_code == 200
    assert started.json()["status"] == "transaction_created"
    return started.json()


def _callback(
    client: TestClient,
    account: dict[str, object],
    transaction: dict[str, object],
    code: str,
):
    return client.post(
        "/auth/identities/wechat/bind/callback",
        headers=_headers(account),
        json={
            "transaction_id": transaction["transaction_id"],
            "state": transaction["state"],
            "nonce": transaction["nonce"],
            "authorization_code": code,
        },
    )


def _headers(account: dict[str, object]) -> dict[str, str]:
    return {"Authorization": f"Bearer {account['access_token']}"}
