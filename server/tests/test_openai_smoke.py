from __future__ import annotations

import asyncio
import json
import os
from pathlib import Path

import pytest

from app.ai.prompts import get_prompt
from app.ai.providers import OpenAiResponsesProvider, ProviderPromptPayload
from app.config import load_settings


@pytest.mark.skipif(
    os.getenv("REBIRTH_RUN_OPENAI_SMOKE") != "1"
    or not os.getenv("OPENAI_API_KEY")
    or not os.getenv("REBIRTH_AI_MODEL"),
    reason="Real OpenAI smoke is opt-in and may incur provider cost.",
)
def test_real_openai_weekly_structured_output_smoke() -> None:
    settings = load_settings(
        environment="test",
        jwt_secret="smoke-test-secret",
        ai_provider="openai",
    )
    provider = OpenAiResponsesProvider(settings)
    prompt = get_prompt("weekly-report-v1")
    assert prompt is not None
    result = asyncio.run(
        provider.generate(
            payload=ProviderPromptPayload(
                report_type="weekly_report",
                prompt_version="weekly-report-v1",
                period={
                    "start_date": "2026-07-10",
                    "end_date": "2026-07-16",
                },
                scopes=["today_metrics"],
                data={"today_metrics": []},
            ),
            prompt=prompt,
            safety_identifier="rebirth-explicit-cost-smoke-test",
        )
    )
    assert result.provider == "openai"
    assert result.model
    assert json.dumps(result.structured_output)
