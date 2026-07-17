from __future__ import annotations

import os
import threading
import uuid
from concurrent.futures import ThreadPoolExecutor

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient

from app.ai.providers import FakeAiProvider
from app.ai.service import AiGenerationService
from app.main import create_app
from tests.test_ai_gateway import request_body


pytestmark = pytest.mark.postgres


class BlockingProvider(FakeAiProvider):
    def __init__(self) -> None:
        super().__init__()
        self.started = threading.Event()
        self.release = threading.Event()

    async def generate(self, **kwargs):
        import asyncio

        self.started.set()
        await asyncio.to_thread(self.release.wait, 10)
        return await super().generate(**kwargs)


@pytest.mark.skipif(
    not os.getenv("REBIRTH_POSTGRES_TEST_URL"),
    reason="REBIRTH_POSTGRES_TEST_URL is not configured",
)
def test_postgres_concurrent_duplicate_claim_calls_provider_once(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    database_url = os.environ["REBIRTH_POSTGRES_TEST_URL"]
    monkeypatch.setenv("REBIRTH_DATABASE_URL", database_url)
    command.upgrade(Config("alembic.ini"), "head")
    app = create_app(
        database_url=database_url,
        environment="development",
        jwt_secret="postgres-ai-test-jwt-secret-at-least-32-bytes",
    )
    provider = BlockingProvider()
    app.state.ai_generation_service = AiGenerationService(
        app.state.settings, provider
    )
    with TestClient(app) as client:
        login = client.post(
            "/auth/dev-login", json={"dev_user_key": "postgres-ai-ledger-user"}
        )
        headers = {
            "Authorization": f"Bearer {login.json()['access_token']}"
        }
        body = request_body()
        body["request_id"] = str(uuid.uuid4())

        def send() -> int:
            return client.post(
                "/ai/reports/weekly/generate",
                headers=headers,
                json=body,
            ).status_code

        with ThreadPoolExecutor(max_workers=2) as executor:
            first = executor.submit(send)
            assert provider.started.wait(10)
            second = executor.submit(send)
            second_status = second.result(timeout=10)
            provider.release.set()
            first_status = first.result(timeout=10)
        assert sorted([first_status, second_status]) == [200, 202]
        assert provider.calls == 1
    app.state.database.engine.dispose()
