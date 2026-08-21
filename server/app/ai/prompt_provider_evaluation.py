from __future__ import annotations

import asyncio
from dataclasses import replace
import math
import os
import time
from typing import Any
import uuid

from sqlalchemy import select

from app.ai.canonical import canonical_json, input_hash
from app.ai.errors import AiGatewayError
from app.ai.prompt_evaluation import (
    DEFAULT_FIXTURE_ROOT,
    PromptEvaluationError,
    evaluate_case,
    load_evaluation_cases,
)
from app.ai.prompts import PROMPT_REGISTRY
from app.ai.providers import build_provider
from app.ai.schemas import (
    AiChatPayload,
    AiChatTurnRequest,
    AiDailyGenerateRequest,
    AiDailyPayload,
    AiWeeklyGenerateRequest,
    AiWeeklyPayload,
)
from app.ai.service import AiGenerationService
from app.config import Settings
from app.database import Database
from app.models import AiUsageRecord, CloudUser


def run_provider_evaluation(
    *,
    settings: Settings,
    prompt_id: str,
    prompt_version: str,
    provider_name: str,
    model: str,
    max_cases: int,
    max_output_tokens: int,
    max_estimated_cost_usd: float,
    input_cost_per_million: float,
    output_cost_per_million: float,
) -> dict[str, Any]:
    if os.getenv("REBIRTH_RUN_PROMPT_PROVIDER_EVAL") != "1":
        raise PromptEvaluationError(
            "real Provider evaluation requires explicit opt-in"
        )
    if provider_name not in {"deepseek", "openai"}:
        raise PromptEvaluationError("real Provider evaluation rejects fake/disabled")
    if settings.ai_provider != provider_name or settings.ai_model != model:
        raise PromptEvaluationError(
            "explicit Provider and model must match Server configuration"
        )
    if max_cases <= 0 or max_output_tokens <= 0:
        raise PromptEvaluationError("Provider evaluation bounds must be positive")
    if max_output_tokens > settings.ai_max_output_tokens:
        raise PromptEvaluationError(
            "evaluation token limit exceeds the configured Server limit"
        )
    if max_estimated_cost_usd <= 0:
        raise PromptEvaluationError("Provider evaluation cost cap must be positive")
    if input_cost_per_million < 0 or output_cost_per_million < 0:
        raise PromptEvaluationError("Provider evaluation prices cannot be negative")
    cloud_user_id = os.getenv("REBIRTH_PROMPT_EVAL_CLOUD_USER_ID")
    if not cloud_user_id:
        raise PromptEvaluationError(
            "REBIRTH_PROMPT_EVAL_CLOUD_USER_ID is required"
        )

    prompt = PROMPT_REGISTRY.get(prompt_id, prompt_version)
    if prompt is None:
        raise PromptEvaluationError("Provider evaluation Prompt was not found")
    cases, _ = load_evaluation_cases(DEFAULT_FIXTURE_ROOT)
    selected = [item for item in cases if item.prompt_id == prompt_id][:max_cases]
    if not selected:
        raise PromptEvaluationError("no synthetic cases match the Prompt")
    estimated_input_tokens = sum(
        _estimated_input_tokens(
            case.input_payload, case.report_type, prompt_version
        )
        for case in selected
    )
    estimated_output_tokens = max_output_tokens * len(selected)
    maximum_cost = _estimated_cost(
        input_tokens=estimated_input_tokens,
        output_tokens=estimated_output_tokens,
        input_cost_per_million=input_cost_per_million,
        output_cost_per_million=output_cost_per_million,
    )
    if maximum_cost > max_estimated_cost_usd:
        raise PromptEvaluationError(
            "worst-case Provider evaluation cost exceeds the explicit cap"
        )

    bounded_settings = replace(
        settings, ai_max_output_tokens=max_output_tokens
    )
    database = Database(settings.database_url)
    try:
        return asyncio.run(
            _evaluate_selected(
                database=database,
                settings=bounded_settings,
                cloud_user_id=cloud_user_id,
                selected=selected,
                prompt_version=prompt_version,
                provider_name=provider_name,
                model=model,
                input_cost_per_million=input_cost_per_million,
                output_cost_per_million=output_cost_per_million,
                maximum_estimated_cost=maximum_cost,
                authorized_cost_cap=max_estimated_cost_usd,
            )
        )
    finally:
        database.engine.dispose()


async def _evaluate_selected(
    *,
    database: Database,
    settings: Settings,
    cloud_user_id: str,
    selected: list[Any],
    prompt_version: str,
    provider_name: str,
    model: str,
    input_cost_per_million: float,
    output_cost_per_million: float,
    maximum_estimated_cost: float,
    authorized_cost_cap: float,
) -> dict[str, Any]:
    provider = build_provider(settings)
    service = AiGenerationService(settings, provider)
    request_ids: list[str] = []
    results: list[dict[str, Any]] = []
    with database.session_factory() as session:
        user_exists = session.scalar(
            select(CloudUser.id).where(CloudUser.id == cloud_user_id)
        )
        if user_exists is None:
            raise PromptEvaluationError(
                "the evaluation CloudUser does not exist"
            )
        for case in selected:
            prompt = PROMPT_REGISTRY.get(case.report_type, prompt_version)
            if prompt is None:
                raise PromptEvaluationError("evaluation Prompt was not found")
            payload_value = dict(case.input_payload)
            payload_value["prompt_version"] = prompt.prompt_version
            request_id = str(uuid.uuid4())
            request_ids.append(request_id)
            started = time.perf_counter_ns()
            try:
                if case.report_type == "coach_chat":
                    payload = AiChatPayload.model_validate(payload_value)
                    request = AiChatTurnRequest(
                        request_id=request_id,
                        input_hash=input_hash(payload),
                        payload=payload,
                    )
                elif case.report_type == "daily_insight":
                    payload = AiDailyPayload.model_validate(payload_value)
                    request = AiDailyGenerateRequest(
                        request_id=request_id,
                        input_hash=input_hash(payload),
                        payload=payload,
                    )
                else:
                    payload = AiWeeklyPayload.model_validate(payload_value)
                    request = AiWeeklyGenerateRequest(
                        request_id=request_id,
                        input_hash=input_hash(payload),
                        payload=payload,
                    )
                response = await service.evaluate_registered_prompt(
                    request, user_id=cloud_user_id, session=session
                )
            except AiGatewayError as error:
                raise PromptEvaluationError(
                    "Provider evaluation stopped with controlled outcome: "
                    f"{error.code}"
                ) from None
            latency_ms = (time.perf_counter_ns() - started) // 1_000_000
            if not hasattr(response, "structured_output"):
                raise PromptEvaluationError(
                    "Provider evaluation did not return a terminal result"
                )
            result = evaluate_case(
                case,
                prompt,
                response.structured_output.model_dump(mode="json"),
            )
            result["request_id"] = request_id
            result["gates"]["operational"] = "pass"
            result["operational"] = {
                "provider": response.provider,
                "model": response.model,
                "input_tokens": "pending_ledger_read",
                "output_tokens": "pending_ledger_read",
                "estimated_cost_usd": "pending_ledger_read",
                "latency_ms": latency_ms,
                "output_characters": len(response.report_content),
            }
            results.append(result)
        usage_rows = session.scalars(
            select(AiUsageRecord).where(
                AiUsageRecord.user_id == cloud_user_id,
                AiUsageRecord.request_id.in_(request_ids),
            )
        ).all()
    usage_by_request = {item.request_id: item for item in usage_rows}
    for result in results:
        request_id = result.pop("request_id")
        usage = usage_by_request.get(request_id)
        if usage is None:
            raise PromptEvaluationError(
                "Provider evaluation Usage Ledger row is missing"
            )
        input_value = usage.input_tokens
        output_value = usage.output_tokens
        case_cost: float | str = "not_reported"
        if input_value is not None and output_value is not None:
            case_cost = _estimated_cost(
                input_tokens=input_value,
                output_tokens=output_value,
                input_cost_per_million=input_cost_per_million,
                output_cost_per_million=output_cost_per_million,
            )
        result["operational"].update(
            {
                "input_tokens": input_value
                if input_value is not None
                else "not_reported",
                "output_tokens": output_value
                if output_value is not None
                else "not_reported",
                "estimated_cost_usd": case_cost,
            }
        )
    tokens_reported = all(
        item.input_tokens is not None and item.output_tokens is not None
        for item in usage_rows
    )
    input_tokens: int | str = "not_reported"
    output_tokens: int | str = "not_reported"
    actual_cost: float | str = "not_reported"
    if tokens_reported:
        input_tokens = sum(
            item.input_tokens
            for item in usage_rows
            if item.input_tokens is not None
        )
        output_tokens = sum(
            item.output_tokens
            for item in usage_rows
            if item.output_tokens is not None
        )
        actual_cost = _estimated_cost(
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            input_cost_per_million=input_cost_per_million,
            output_cost_per_million=output_cost_per_million,
        )
    failed = [item for item in results if item["status"] != "pass"]
    cost_cap_exceeded: bool | str = "not_reported"
    if isinstance(actual_cost, float):
        cost_cap_exceeded = actual_cost > authorized_cost_cap
    quality_passed = not failed and cost_cap_exceeded is not True
    latencies = [item["operational"]["latency_ms"] for item in results]
    return {
        "status": "pass" if quality_passed else "fail",
        "level": 3,
        "synthetic_only": True,
        "provider": provider_name,
        "model": model,
        "prompt_fingerprints": sorted(
            {item["prompt_fingerprint"] for item in results}
        ),
        "case_count": len(results),
        "failed_count": len(failed),
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "estimated_cost_usd": actual_cost,
        "maximum_estimated_cost_usd": maximum_estimated_cost,
        "authorized_cost_cap_usd": authorized_cost_cap,
        "cost_cap_exceeded": cost_cap_exceeded,
        "total_latency_ms": sum(latencies),
        "maximum_case_latency_ms": max(latencies),
        "timeout_count": 0,
        "controlled_failure_count": 0,
        "usage_ledger_written": True,
        "generation_ledger_written": True,
        "ai_report_created": False,
        "results": results,
    }


def _estimated_input_tokens(
    payload: dict[str, Any], report_type: str, prompt_version: str
) -> int:
    prompt = PROMPT_REGISTRY.get(report_type, prompt_version)
    if prompt is None:
        raise PromptEvaluationError("evaluation Prompt was not found")
    characters = len(canonical_json(payload)) + len(prompt.developer_instructions)
    return math.ceil(characters)


def _estimated_cost(
    *,
    input_tokens: int,
    output_tokens: int,
    input_cost_per_million: float,
    output_cost_per_million: float,
) -> float:
    value = (
        input_tokens * input_cost_per_million
        + output_tokens * output_cost_per_million
    ) / 1_000_000
    return round(value, 8)
