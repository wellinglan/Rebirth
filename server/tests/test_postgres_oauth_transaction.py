from __future__ import annotations

import os
import uuid
from concurrent.futures import ThreadPoolExecutor

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.identity import VerifiedWechatIdentity
from app.main import create_app
from app.models import AuthIdentity, OAuthTransaction
from app.oauth.providers import FakeWechatProvider
from app.oauth.service import (
    OAuthPurpose,
    OAuthTransactionError,
    OAuthTransactionService,
)


pytestmark = [
    pytest.mark.postgres,
    pytest.mark.skipif(
        not os.getenv("REBIRTH_POSTGRES_TEST_URL"),
        reason="REBIRTH_POSTGRES_TEST_URL is not configured",
    ),
]


def test_postgres_concurrent_oauth_exchange_has_one_winner() -> None:
    database_url = os.environ["REBIRTH_POSTGRES_TEST_URL"]
    command.upgrade(Config("alembic.ini"), "head")
    unique = uuid.uuid4().hex
    app = create_app(
        database_url=database_url,
        environment="test",
        jwt_secret="postgres-oauth-jwt-secret-at-least-32-bytes",
        auth_refresh_token_hmac_key=(
            "postgres-oauth-refresh-secret-at-least-32-bytes"
        ),
        auth_dev_identity_hmac_key=(
            "postgres-oauth-dev-secret-at-least-32-bytes"
        ),
        auth_rate_limit_hmac_key=(
            "postgres-oauth-rate-secret-at-least-32-bytes"
        ),
        wechat_app_id="postgres-test-app",
        wechat_app_secret="postgres-test-secret-not-real",
        wechat_provider_adapter=FakeWechatProvider(
            {
                "concurrent-code": VerifiedWechatIdentity(
                    "postgres-test-app",
                    f"openid-{unique}",
                    f"union-{unique}",
                )
            }
        ),
    )
    try:
        with TestClient(app) as client:
            registered = client.post(
                "/auth/register",
                json={
                    "username": f"oauth_{unique}",
                    "password": "correct horse battery staple",
                },
            ).json()
            proof = client.post(
                "/auth/reauthenticate/password",
                headers={
                    "Authorization": f"Bearer {registered['access_token']}"
                },
                json={
                    "password": "correct horse battery staple",
                    "purpose": "wechat_bind",
                },
            ).json()
            started = client.post(
                "/auth/identities/wechat/bind/start",
                headers={
                    "Authorization": f"Bearer {registered['access_token']}"
                },
                json={"reauthentication_proof": proof["proof"]},
            ).json()

            def exchange() -> str:
                with app.state.database.session_factory() as session:
                    service = OAuthTransactionService(
                        session,
                        providers=app.state.oauth_provider_registry,
                        transaction_minutes=(
                            app.state.settings.wechat_oauth_transaction_minutes
                        ),
                    )
                    try:
                        service.exchange(
                            transaction_id=started["transaction_id"],
                            provider="wechat",
                            purpose=OAuthPurpose.WECHAT_BIND,
                            cloud_user_id=registered["user"]["id"],
                            session_id=registered["session_id"],
                            state=started["state"],
                            nonce=started["nonce"],
                            authorization_code="concurrent-code",
                        )
                        return "completed"
                    except OAuthTransactionError as error:
                        return error.code

            with ThreadPoolExecutor(max_workers=2) as executor:
                results = list(executor.map(lambda _: exchange(), range(2)))

            assert sorted(results) == [
                "already_consumed",
                "completed",
            ]
            with app.state.database.session_factory() as session:
                transaction = session.get_one(
                    OAuthTransaction,
                    started["transaction_id"],
                )
                identities = session.scalars(
                    select(AuthIdentity).where(
                        AuthIdentity.provider == "wechat",
                        AuthIdentity.provider_subject == f"unionid:union-{unique}",
                    )
                ).all()
                assert transaction.status == "consumed"
                assert len(identities) == 1
    finally:
        app.state.database.engine.dispose()
