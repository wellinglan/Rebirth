from __future__ import annotations

from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, inspect, select, text

from app.identity import VerifiedWechatIdentity
from app.config import load_settings
from app.main import create_app
from app.models import AuthIdentity, OAuthTransaction
from app.oauth.providers import FakeWechatProvider
from app.oauth.service import (
    OAuthPurpose,
    OAuthTransactionError,
    OAuthTransactionService,
    OAuthTransactionStateMachine,
    OAuthTransactionStatus,
)


class _Clock:
    def __init__(self, value: int = 1_000_000) -> None:
        self.value = value

    def __call__(self) -> int:
        return self.value


@pytest.fixture
def oauth_client(tmp_path: Path) -> object:
    clock = _Clock()
    database_file = tmp_path / "rebirth_oauth.sqlite"
    provider = FakeWechatProvider(
        {
            "valid-code-a": VerifiedWechatIdentity(
                "test-app",
                "openid-a",
                "union-a",
            ),
            "valid-code-b": VerifiedWechatIdentity(
                "test-app",
                "openid-b",
                "union-b",
            ),
            "shared-code": VerifiedWechatIdentity(
                "test-app",
                "shared-openid",
                "shared-union",
            ),
        }
    )
    app = create_app(
        database_url=f"sqlite:///{database_file.as_posix()}",
        environment="development",
        jwt_secret="oauth-test-jwt-secret-at-least-32-bytes",
        wechat_app_id="test-wechat-app-id",
        wechat_app_secret="test-wechat-app-secret-not-real",
        wechat_provider_adapter=provider,
        oauth_clock=clock,
    )
    with TestClient(app) as client:
        yield client, clock
    app.state.database.engine.dispose()


def test_start_creates_hashed_persistent_transaction(oauth_client: object) -> None:
    client, _ = oauth_client
    account = _register(client, "oauth-start")

    response = _start(client, account["access_token"])

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "transaction_created"
    assert body["provider"] == "wechat"
    assert body["purpose"] == "wechat_bind"
    assert body["requires_reauthentication"] is False
    with client.app.state.database.session_factory() as session:
        transaction = session.get_one(
            OAuthTransaction,
            body["transaction_id"],
        )
        assert transaction.cloud_user_id == account["user"]["id"]
        assert transaction.session_id == account["session_id"]
        assert transaction.status == "created"
        assert transaction.state_hash != body["state"]
        assert transaction.nonce_hash != body["nonce"]
        assert len(transaction.state_hash) == 64
        assert len(transaction.nonce_hash) == 64


def test_state_mismatch_is_rejected_without_destroying_valid_flow(
    oauth_client: object,
) -> None:
    client, _ = oauth_client
    account = _register(client, "oauth-state")
    started = _start(client, account["access_token"]).json()

    with client.app.state.database.session_factory() as session:
        service = _service(client, session)
        with pytest.raises(OAuthTransactionError) as rejected:
            _exchange(
                service,
                started,
                account,
                state="wrong-state",
                authorization_code="valid-code-a",
            )
        assert rejected.value.code == "invalid_transaction"

    with client.app.state.database.session_factory() as session:
        result = _exchange(
            _service(client, session),
            started,
            account,
            authorization_code="valid-code-a",
        )
        assert result.status == "completed"


def test_nonce_mismatch_and_replay_are_rejected(oauth_client: object) -> None:
    client, _ = oauth_client
    account = _register(client, "oauth-nonce")
    started = _start(client, account["access_token"]).json()

    with client.app.state.database.session_factory() as session:
        with pytest.raises(OAuthTransactionError) as rejected:
            _exchange(
                _service(client, session),
                started,
                account,
                nonce="wrong-nonce",
                authorization_code="valid-code-a",
            )
        assert rejected.value.code == "invalid_transaction"

    with client.app.state.database.session_factory() as session:
        _exchange(
            _service(client, session),
            started,
            account,
            authorization_code="valid-code-a",
        )
    with client.app.state.database.session_factory() as session:
        with pytest.raises(OAuthTransactionError) as replay:
            _exchange(
                _service(client, session),
                started,
                account,
                authorization_code="valid-code-a",
            )
        assert replay.value.code == "already_consumed"
        transaction = session.get_one(
            OAuthTransaction,
            started["transaction_id"],
        )
        assert transaction.status == "consumed"
        assert transaction.consumed_at is not None


def test_expired_transaction_cannot_continue(oauth_client: object) -> None:
    client, clock = oauth_client
    account = _register(client, "oauth-expired")
    started = _start(client, account["access_token"]).json()
    clock.value = started["expires_at"]

    with client.app.state.database.session_factory() as session:
        with pytest.raises(OAuthTransactionError) as expired:
            _exchange(
                _service(client, session),
                started,
                account,
                authorization_code="valid-code-a",
            )
        assert expired.value.code == "expired_transaction"
    with client.app.state.database.session_factory() as session:
        transaction = session.get_one(
            OAuthTransaction,
            started["transaction_id"],
        )
        assert transaction.status == "expired"


def test_account_cannot_exchange_another_accounts_transaction(
    oauth_client: object,
) -> None:
    client, _ = oauth_client
    account_a = _register(client, "oauth-account-a")
    account_b = _register(client, "oauth-account-b")
    started = _start(client, account_a["access_token"]).json()

    with client.app.state.database.session_factory() as session:
        with pytest.raises(OAuthTransactionError) as rejected:
            _exchange(
                _service(client, session),
                started,
                account_b,
                authorization_code="valid-code-a",
            )
        assert rejected.value.code == "invalid_transaction"
    with client.app.state.database.session_factory() as session:
        transaction = session.get_one(
            OAuthTransaction,
            started["transaction_id"],
        )
        assert transaction.status == "created"
        assert (
            session.scalar(
                select(AuthIdentity).where(AuthIdentity.provider == "wechat")
            )
            is None
        )


def test_same_provider_identity_cannot_bind_two_cloud_users(
    oauth_client: object,
) -> None:
    client, _ = oauth_client
    account_a = _register(client, "oauth-owner-a")
    account_b = _register(client, "oauth-owner-b")
    first = _start(client, account_a["access_token"]).json()
    second = _start(client, account_b["access_token"]).json()

    with client.app.state.database.session_factory() as session:
        _exchange(
            _service(client, session),
            first,
            account_a,
            authorization_code="shared-code",
        )
    with client.app.state.database.session_factory() as session:
        with pytest.raises(OAuthTransactionError) as duplicate:
            _exchange(
                _service(client, session),
                second,
                account_b,
                authorization_code="shared-code",
            )
        assert duplicate.value.code == "binding_conflict"

    with client.app.state.database.session_factory() as session:
        identity = session.scalar(
            select(AuthIdentity).where(AuthIdentity.provider == "wechat")
        )
        rejected = session.get_one(
            OAuthTransaction,
            second["transaction_id"],
        )
        assert identity is not None
        assert identity.user_id == account_a["user"]["id"]
        assert rejected.status == "rejected"


def test_reauthentication_proof_is_required_before_transaction_start(
    oauth_client: object,
) -> None:
    client, _ = oauth_client
    account = _register(client, "oauth-reauth")

    missing = client.post(
        "/auth/identities/wechat/bind/start",
        headers={"Authorization": f"Bearer {account['access_token']}"},
        json={},
    )
    invalid = client.post(
        "/auth/identities/wechat/bind/start",
        headers={"Authorization": f"Bearer {account['access_token']}"},
        json={"reauthentication_proof": "not-a-proof"},
    )

    assert missing.status_code == 422
    assert invalid.status_code == 403
    assert invalid.json()["detail"]["code"] == "reauthentication_proof_invalid"


def test_provider_failure_is_terminal_and_does_not_create_identity(
    oauth_client: object,
) -> None:
    client, _ = oauth_client
    account = _register(client, "oauth-rejected")
    started = _start(client, account["access_token"]).json()

    with client.app.state.database.session_factory() as session:
        with pytest.raises(OAuthTransactionError) as rejected:
            _exchange(
                _service(client, session),
                started,
                account,
                authorization_code="invalid-code",
            )
        assert rejected.value.code == "provider_error"
    with client.app.state.database.session_factory() as session:
        transaction = session.get_one(
            OAuthTransaction,
            started["transaction_id"],
        )
        assert transaction.status == "rejected"
        assert (
            session.scalar(
                select(AuthIdentity).where(AuthIdentity.provider == "wechat")
            )
            is None
        )


def test_state_machine_does_not_allow_status_regression() -> None:
    transaction = OAuthTransaction(status="provider_verified")

    with pytest.raises(OAuthTransactionError):
        OAuthTransactionStateMachine.transition(
            transaction,
            OAuthTransactionStatus.CREATED,
        )


def test_unconfigured_provider_fails_closed(client: TestClient) -> None:
    account = _register(client, "oauth-disabled")

    response = _start(client, account["access_token"])

    assert response.status_code == 200
    assert response.json()["status"] == "provider_unavailable"
    with client.app.state.database.session_factory() as session:
        assert session.scalar(select(OAuthTransaction)) is None


def test_credentials_without_adapter_still_fail_closed(tmp_path: Path) -> None:
    database_file = tmp_path / "rebirth_oauth_no_adapter.sqlite"
    app = create_app(
        database_url=f"sqlite:///{database_file.as_posix()}",
        environment="development",
        jwt_secret="oauth-no-adapter-jwt-secret-at-least-32-bytes",
        wechat_app_id="test-wechat-app-id",
        wechat_app_secret="test-wechat-app-secret-not-real",
    )
    try:
        with TestClient(app) as client:
            account = _register(client, "oauth-no-adapter")
            response = _start(client, account["access_token"])
            assert response.status_code == 200
            assert response.json()["status"] == "provider_unavailable"
    finally:
        app.state.database.engine.dispose()


def test_partial_provider_configuration_is_rejected(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.delenv("REBIRTH_WECHAT_APP_ID", raising=False)
    monkeypatch.delenv("REBIRTH_WECHAT_APP_SECRET", raising=False)

    with pytest.raises(RuntimeError, match="must be configured together"):
        load_settings(
            environment="development",
            jwt_secret="test-secret",
            wechat_app_id="only-an-app-id",
        )


def test_provider_configuration_secrets_are_not_logged_or_represented(
    oauth_client: object,
    caplog: pytest.LogCaptureFixture,
) -> None:
    client, _ = oauth_client
    account = _register(client, "oauth-private-config")

    response = _start(client, account["access_token"])

    assert response.status_code == 200
    evidence = f"{client.app.state.settings!r}\n{caplog.text}\n{response.text}"
    assert "test-wechat-app-id" not in evidence
    assert "test-wechat-app-secret-not-real" not in evidence


def test_oauth_table_has_no_code_token_or_secret_columns() -> None:
    columns = {column.name for column in OAuthTransaction.__table__.columns}

    assert columns == {
        "transaction_id",
        "provider",
        "purpose",
        "cloud_user_id",
        "session_id",
        "state_hash",
        "nonce_hash",
        "status",
        "created_at",
        "expires_at",
        "consumed_at",
    }


def test_oauth_migration_upgrades_downgrades_and_preserves_user(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    database_path = tmp_path / "oauth_migration.sqlite"
    database_url = f"sqlite:///{database_path.as_posix()}"
    monkeypatch.setenv("REBIRTH_DATABASE_URL", database_url)
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", database_url)
    command.upgrade(config, "20260731_0004")
    engine = create_engine(database_url)
    with engine.begin() as connection:
        connection.execute(
            text(
                "INSERT INTO cloud_users "
                "(id, display_name, created_at, updated_at, deleted_at) "
                "VALUES ('preserved-user', 'Preserved', 1, 1, NULL)"
            )
        )

    command.upgrade(config, "head")
    assert "oauth_transactions" in inspect(engine).get_table_names()
    assert "reauthentication_proofs" in inspect(engine).get_table_names()
    command.downgrade(config, "20260731_0005")
    assert "oauth_transactions" in inspect(engine).get_table_names()
    assert "reauthentication_proofs" not in inspect(engine).get_table_names()
    with engine.connect() as connection:
        assert connection.scalar(
            text("SELECT display_name FROM cloud_users WHERE id='preserved-user'")
        ) == "Preserved"
    command.upgrade(config, "head")
    assert "oauth_transactions" in inspect(engine).get_table_names()
    engine.dispose()


def _service(client: TestClient, session: object) -> OAuthTransactionService:
    return OAuthTransactionService(
        session,
        providers=client.app.state.oauth_provider_registry,
        transaction_minutes=(
            client.app.state.settings.wechat_oauth_transaction_minutes
        ),
        clock=client.app.state.oauth_clock,
    )


def _exchange(
    service: OAuthTransactionService,
    started: dict[str, object],
    account: dict[str, object],
    *,
    state: str | None = None,
    nonce: str | None = None,
    authorization_code: str,
):
    return service.exchange(
        transaction_id=str(started["transaction_id"]),
        provider="wechat",
        purpose=OAuthPurpose.WECHAT_BIND,
        cloud_user_id=str(account["user"]["id"]),
        session_id=str(account["session_id"]),
        state=state or str(started["state"]),
        nonce=nonce or str(started["nonce"]),
        authorization_code=authorization_code,
    )


def _register(client: TestClient, username: str) -> dict[str, object]:
    response = client.post(
        "/auth/register",
        json={
            "username": username,
            "password": "correct horse battery staple",
        },
    )
    assert response.status_code == 200
    return response.json()


def _start(client: TestClient, access_token: str):
    proof = client.post(
        "/auth/reauthenticate/password",
        headers={"Authorization": f"Bearer {access_token}"},
        json={
            "password": "correct horse battery staple",
            "purpose": "wechat_bind",
        },
    )
    assert proof.status_code == 200
    return client.post(
        "/auth/identities/wechat/bind/start",
        headers={"Authorization": f"Bearer {access_token}"},
        json={"reauthentication_proof": proof.json()["proof"]},
    )
