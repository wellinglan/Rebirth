from __future__ import annotations

import copy
from dataclasses import dataclass

from pydantic import ValidationError

from app.ai.canonical import input_hash
from app.ai.errors import (
    AiGatewayError,
    InputHashMismatchError,
    UnsupportedContractError,
)
from app.ai.prompts import WEEKLY_PROMPT_VERSION, get_prompt
from app.ai.providers import AiProvider, ProviderPromptPayload, safety_identifier
from app.ai.schemas import (
    AiCapabilitiesResponse,
    AiWeeklyGenerateRequest,
    AiWeeklyGenerateResponse,
    AiWeeklyStructuredOutput,
)
from app.config import Settings


SUPPORTED_SCOPES = {
    "growth_summary",
    "today_metrics",
    "health_metrics",
    "journal_reflections",
}


@dataclass(frozen=True)
class AiGenerationService:
    settings: Settings
    provider: AiProvider

    def capabilities(self) -> AiCapabilitiesResponse:
        return AiCapabilitiesResponse(
            enabled=self.provider.enabled,
            provider=self.provider.name,
            provider_label=self.provider.label,
            model=self.provider.model,
            supported_report_types=["weekly_report"],
            prompt_versions=[WEEKLY_PROMPT_VERSION],
        )

    async def generate_weekly(
        self, request: AiWeeklyGenerateRequest, *, user_id: str
    ) -> AiWeeklyGenerateResponse:
        payload = request.payload
        if payload.schema_version != 1:
            raise UnsupportedContractError("invalid_input")
        if payload.report_type != "weekly_report":
            raise UnsupportedContractError("unsupported_report_type")
        prompt = get_prompt(payload.prompt_version)
        if prompt is None:
            raise UnsupportedContractError("unsupported_prompt_version")
        if any(scope not in SUPPORTED_SCOPES for scope in payload.scopes):
            raise UnsupportedContractError("unsupported_scope")
        verified_hash = input_hash(payload)
        if verified_hash != request.input_hash:
            raise InputHashMismatchError()

        provider_payload = _provider_payload(request)
        generation = await self.provider.generate(
            payload=provider_payload,
            prompt=prompt,
            safety_identifier=safety_identifier(user_id, self.settings.environment),
        )
        try:
            structured = AiWeeklyStructuredOutput.model_validate(
                generation.structured_output
            )
        except ValidationError:
            raise AiGatewayError("response_invalid") from None
        return AiWeeklyGenerateResponse(
            request_id=request.request_id,
            input_hash=verified_hash,
            provider=generation.provider,
            model=generation.model,
            report_content=render_markdown(structured),
            structured_output=structured,
        )


def _provider_payload(request: AiWeeklyGenerateRequest) -> ProviderPromptPayload:
    payload = request.payload.model_dump(mode="json", exclude_none=False)
    payload["data"] = {
        key: item for key, item in payload["data"].items() if item is not None
    }
    selected_data = {
        scope: copy.deepcopy(payload["data"][scope]) for scope in payload["scopes"]
    }
    growth = selected_data.get("growth_summary")
    if isinstance(growth, dict):
        growth["is_derived_summary"] = True
    return ProviderPromptPayload(
        report_type=payload["report_type"],
        prompt_version=payload["prompt_version"],
        period=payload["period"],
        scopes=sorted(payload["scopes"]),
        data=selected_data,
    )


def render_markdown(output: AiWeeklyStructuredOutput) -> str:
    lines = [f"# {output.title}", "", output.summary]
    if output.observations:
        lines.extend(["", "## 观察"])
        for item in output.observations:
            evidence = "；".join(item.evidence)
            suffix = f"（依据：{evidence}）" if evidence else ""
            lines.append(f"- {item.statement}{suffix}")
    if output.suggestions:
        lines.extend(["", "## 可选建议"])
        for item in output.suggestions:
            lines.append(f"- {item.action}：{item.reason}")
    if output.data_limitations:
        lines.extend(["", "## 数据限制"])
        lines.extend(f"- {item}" for item in output.data_limitations)
    return "\n".join(lines).strip()
