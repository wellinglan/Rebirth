from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from typing import Any, Protocol

from pydantic import ValidationError

from app.ai.canonical import canonical_json
from app.ai.errors import AiGatewayError, GatewayDisabledError
from app.ai.prompts import PromptDefinition
from app.config import Settings


@dataclass(frozen=True)
class ProviderPromptPayload:
    report_type: str
    prompt_version: str
    period: dict[str, str]
    scopes: list[str]
    data: dict[str, Any]

    def to_json_value(self) -> dict[str, Any]:
        return {
            "report_type": self.report_type,
            "prompt_version": self.prompt_version,
            "period": self.period,
            "scopes": self.scopes,
            "data": self.data,
        }


@dataclass(frozen=True)
class ProviderGeneration:
    provider: str
    model: str
    structured_output: dict[str, Any]


class AiProvider(Protocol):
    @property
    def name(self) -> str: ...

    @property
    def label(self) -> str: ...

    @property
    def model(self) -> str | None: ...

    @property
    def enabled(self) -> bool: ...

    async def generate(
        self,
        *,
        payload: ProviderPromptPayload,
        prompt: PromptDefinition,
        safety_identifier: str,
    ) -> ProviderGeneration: ...


class DisabledAiProvider:
    name = "disabled"
    label = "Disabled"
    model = None
    enabled = False

    async def generate(
        self,
        *,
        payload: ProviderPromptPayload,
        prompt: PromptDefinition,
        safety_identifier: str,
    ) -> ProviderGeneration:
        raise GatewayDisabledError()


class FakeAiProvider:
    name = "fake"
    label = "Development Fake"
    model = "deterministic-test-provider"
    enabled = True

    def __init__(self, scenario: str = "success") -> None:
        self.scenario = scenario
        self.calls = 0
        self.last_payload: ProviderPromptPayload | None = None

    async def generate(
        self,
        *,
        payload: ProviderPromptPayload,
        prompt: PromptDefinition,
        safety_identifier: str,
    ) -> ProviderGeneration:
        self.calls += 1
        self.last_payload = payload
        if self.scenario == "timeout":
            raise AiGatewayError("provider_timeout", status_code=504)
        if self.scenario == "refusal":
            raise AiGatewayError("provider_refused", status_code=422)
        if self.scenario == "unavailable":
            raise AiGatewayError("provider_unavailable", status_code=503)
        if self.scenario == "invalid":
            output: dict[str, Any] = {"title": "invalid"}
        elif self.scenario == "success":
            output = _fake_success_output(payload)
        else:
            raise AiGatewayError("request_failed")
        return ProviderGeneration(
            provider=self.name,
            model=self.model,
            structured_output=output,
        )


class OpenAiResponsesProvider:
    name = "openai"
    label = "OpenAI"
    enabled = True

    def __init__(self, settings: Settings, *, client: Any | None = None) -> None:
        self.model = settings.ai_model
        self._timeout = settings.ai_timeout_seconds
        self._max_output_tokens = settings.ai_max_output_tokens
        if client is None:
            from openai import AsyncOpenAI

            client = AsyncOpenAI(
                api_key=settings.openai_api_key,
                timeout=self._timeout,
                max_retries=0,
            )
        self._client = client

    async def generate(
        self,
        *,
        payload: ProviderPromptPayload,
        prompt: PromptDefinition,
        safety_identifier: str,
    ) -> ProviderGeneration:
        try:
            response = await self._client.responses.create(
                model=self.model,
                instructions=prompt.developer_instructions,
                input=[
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "input_text",
                                "text": canonical_json(payload.to_json_value()),
                            }
                        ],
                    }
                ],
                text={
                    "format": {
                        "type": "json_schema",
                        "name": prompt.schema_name,
                        "schema": prompt.output_schema,
                        "strict": True,
                    }
                },
                store=False,
                stream=False,
                tools=[],
                max_output_tokens=self._max_output_tokens,
                safety_identifier=safety_identifier,
                timeout=self._timeout,
            )
        except Exception as error:
            raise _map_openai_error(error) from None

        if _contains_refusal(response):
            raise AiGatewayError("provider_refused", status_code=422)
        try:
            raw_output = response.output_text
            decoded = json.loads(raw_output)
            structured = prompt.output_model.model_validate(decoded)
        except (AttributeError, TypeError, json.JSONDecodeError, ValidationError):
            raise AiGatewayError("response_invalid") from None
        actual_model = getattr(response, "model", None) or self.model
        return ProviderGeneration(
            provider=self.name,
            model=str(actual_model),
            structured_output=structured.model_dump(mode="json"),
        )


def safety_identifier(user_id: str, environment: str) -> str:
    source = f"rebirth:{environment}:ai-safety:{user_id}".encode("utf-8")
    return hashlib.sha256(source).hexdigest()


def build_provider(settings: Settings, *, openai_client: Any | None = None) -> AiProvider:
    if settings.ai_provider == "disabled":
        return DisabledAiProvider()
    if settings.ai_provider == "fake":
        return FakeAiProvider(settings.ai_fake_scenario)
    return OpenAiResponsesProvider(settings, client=openai_client)


def _fake_success_output(payload: ProviderPromptPayload) -> dict[str, Any]:
    if payload.report_type == "daily_insight":
        missing_scopes = [
            scope
            for scope in payload.scopes
            if isinstance(payload.data.get(scope), list)
            and not payload.data.get(scope)
        ]
        limitations = ["This output comes from the deterministic Fake Provider."]
        limitations.extend(
            f"No record was supplied for selected scope {scope}."
            for scope in missing_scopes
        )
        return {
            "title": "Daily Insight development check",
            "summary": "A deterministic result for the selected single-day data.",
            "observations": [
                {
                    "statement": "The selected data was evaluated for one local date.",
                    "evidence": [payload.period["start_date"]],
                }
            ],
            "possible_factors": [
                {
                    "factor": "Recorded metrics may be related on this date.",
                    "caveat": "One day of data cannot establish causation.",
                }
            ],
            "tomorrow_adjustments": [
                {
                    "action": "Optionally repeat one low-burden helpful routine.",
                    "reason": "This is a small experiment, not a required action.",
                }
            ],
            "data_limitations": limitations,
        }
    return {
        "title": "开发测试每周回顾",
        "summary": "这是 Fake Provider 生成的确定性开发测试结果。",
        "observations": [
            {
                "statement": "已按明确选择的范围读取七天数据。",
                "evidence": [
                    f"{payload.period['start_date']} 至 {payload.period['end_date']}"
                ],
            }
        ],
        "suggestions": [
            {
                "action": "结合原始记录核对本回顾。",
                "reason": "Fake 输出仅用于验证生成链路。",
            }
        ],
        "data_limitations": ["这不是来自真实 AI 模型的分析。"],
    }


def _contains_refusal(response: Any) -> bool:
    for item in getattr(response, "output", []) or []:
        for content in getattr(item, "content", []) or []:
            if getattr(content, "type", None) == "refusal":
                return True
    return False


def _map_openai_error(error: Exception) -> AiGatewayError:
    try:
        from openai import (
            APIConnectionError,
            APIStatusError,
            APITimeoutError,
            AuthenticationError,
            RateLimitError,
        )

        if isinstance(error, AuthenticationError):
            return AiGatewayError("provider_authentication_failed", status_code=502)
        if isinstance(error, RateLimitError):
            return AiGatewayError("provider_rate_limited", status_code=429)
        if isinstance(error, APITimeoutError):
            return AiGatewayError("provider_timeout", status_code=504)
        if isinstance(error, APIConnectionError):
            return AiGatewayError("provider_unavailable", status_code=503)
        if isinstance(error, APIStatusError) and error.status_code >= 500:
            return AiGatewayError("provider_unavailable", status_code=503)
    except ImportError:
        pass
    return AiGatewayError("request_failed")
