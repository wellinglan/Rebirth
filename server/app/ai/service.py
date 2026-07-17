from __future__ import annotations

import copy
import time
from collections.abc import Callable
from dataclasses import dataclass

from pydantic import ValidationError
from sqlalchemy.orm import Session

from app.ai.canonical import input_hash
from app.ai.errors import (
    AiGatewayError,
    IdempotencyConflictError,
    InputHashMismatchError,
    UnsupportedContractError,
)
from app.ai.ledger import AiRequestLedger
from app.ai.observability import log_ai_event
from app.ai.prompts import WEEKLY_PROMPT_VERSION, get_prompt
from app.ai.providers import AiProvider, ProviderPromptPayload, safety_identifier
from app.ai.schemas import (
    AiCapabilitiesResponse,
    AiRequestStatusResponse,
    AiWeeklyGenerateRequest,
    AiWeeklyGenerateResponse,
    AiWeeklyStructuredOutput,
)
from app.config import Settings
from app.models import AiGenerationRequest


SUPPORTED_SCOPES = {
    "growth_summary",
    "today_metrics",
    "health_metrics",
    "journal_reflections",
}


def utc_milliseconds() -> int:
    return time.time_ns() // 1_000_000


@dataclass(frozen=True)
class AiGenerationService:
    settings: Settings
    provider: AiProvider
    clock: Callable[[], int] = utc_milliseconds

    @property
    def ledger(self) -> AiRequestLedger:
        return AiRequestLedger(self.settings)

    def capabilities(self) -> AiCapabilitiesResponse:
        return AiCapabilitiesResponse(
            enabled=self.provider.enabled,
            provider=self.provider.name,
            provider_label=self.provider.label,
            model=self.provider.model,
            supported_report_types=["weekly_report"],
            prompt_versions=[WEEKLY_PROMPT_VERSION],
            result_retention_hours=self.settings.ai_result_retention_hours,
            dedupe_retention_days=self.settings.ai_dedupe_retention_days,
            processing_lease_minutes=self.settings.ai_processing_lease_minutes,
        )

    async def generate_weekly(
        self,
        request: AiWeeklyGenerateRequest,
        *,
        user_id: str,
        session: Session,
    ) -> AiWeeklyGenerateResponse | AiRequestStatusResponse:
        now = self.clock()
        self.ledger.cleanup(session, now=now)
        existing = self.ledger.find(
            session,
            user_id=user_id,
            request_id=str(request.request_id),
        )
        if existing is not None:
            verified_hash = input_hash(request.payload)
            if verified_hash != request.input_hash:
                raise InputHashMismatchError()
            return self._resolve_existing(
                session,
                existing,
                request=request,
                user_id=user_id,
                now=now,
            )

        prompt = self._validate_supported_contract(request)
        verified_hash = input_hash(request.payload)
        if verified_hash != request.input_hash:
            raise InputHashMismatchError()
        claim = self.ledger.claim(
            session,
            user_id=user_id,
            request=request,
            now=now,
        )
        if not claim.owns_provider_call:
            return self._resolve_existing(
                session,
                claim.row,
                request=request,
                user_id=user_id,
                now=now,
            )

        log_ai_event(
            "ai_request_claimed",
            environment=self.settings.environment,
            user_id=user_id,
            request_id=str(request.request_id),
            input_hash=verified_hash,
            status="processing",
        )

        provider_payload = _provider_payload(request)
        provider_started = time.perf_counter_ns()
        log_ai_event(
            "ai_provider_started",
            environment=self.settings.environment,
            user_id=user_id,
            request_id=str(request.request_id),
            input_hash=verified_hash,
            provider=self.provider.name,
            model=self.provider.model,
            status="processing",
        )
        try:
            generation = await self.provider.generate(
                payload=provider_payload,
                prompt=prompt,
                safety_identifier=safety_identifier(
                    user_id, self.settings.environment
                ),
            )
            try:
                structured = AiWeeklyStructuredOutput.model_validate(
                    generation.structured_output
                )
            except ValidationError:
                raise AiGatewayError("response_invalid") from None
            result = AiWeeklyGenerateResponse(
                request_id=request.request_id,
                input_hash=verified_hash,
                provider=generation.provider,
                model=generation.model,
                report_content=render_markdown(structured),
                structured_output=structured,
            )
        except AiGatewayError as error:
            latency_ms = (time.perf_counter_ns() - provider_started) // 1_000_000
            log_ai_event(
                "ai_provider_failed",
                environment=self.settings.environment,
                user_id=user_id,
                request_id=str(request.request_id),
                input_hash=verified_hash,
                provider=self.provider.name,
                model=self.provider.model,
                status="failed",
                error_code=error.code,
                latency_ms=latency_ms,
            )
            self.ledger.mark_failed(
                session,
                claim.row,
                error,
                provider=self.provider.name if self.provider.enabled else None,
                model=self.provider.model,
                now=self.clock(),
            )
            raise
        except Exception:
            controlled = AiGatewayError("request_failed")
            latency_ms = (time.perf_counter_ns() - provider_started) // 1_000_000
            log_ai_event(
                "ai_provider_failed",
                environment=self.settings.environment,
                user_id=user_id,
                request_id=str(request.request_id),
                input_hash=verified_hash,
                provider=self.provider.name,
                model=self.provider.model,
                status="failed",
                error_code=controlled.code,
                latency_ms=latency_ms,
            )
            self.ledger.mark_failed(
                session,
                claim.row,
                controlled,
                provider=self.provider.name if self.provider.enabled else None,
                model=self.provider.model,
                now=self.clock(),
            )
            raise controlled from None

        self.ledger.mark_completed(
            session, claim.row, result, now=self.clock()
        )
        log_ai_event(
            "ai_provider_completed",
            environment=self.settings.environment,
            user_id=user_id,
            request_id=str(request.request_id),
            input_hash=verified_hash,
            provider=result.provider,
            model=result.model,
            status="completed",
            latency_ms=(time.perf_counter_ns() - provider_started) // 1_000_000,
        )
        return result

    def get_request_status(
        self,
        request_id: str,
        *,
        user_id: str,
        session: Session,
    ) -> AiRequestStatusResponse | None:
        now = self.clock()
        self.ledger.cleanup(session, now=now)
        row = self.ledger.find(
            session, user_id=user_id, request_id=request_id
        )
        if row is None:
            return None
        row = self.ledger.normalize_existing(session, row, now=now)
        log_ai_event(
            "ai_status_recovered",
            environment=self.settings.environment,
            user_id=user_id,
            request_id=row.request_id,
            input_hash=row.input_hash,
            provider=row.provider,
            model=row.model,
            status=row.status,
            error_code=row.error_code,
        )
        return self.ledger.status_response(row)

    def _validate_supported_contract(self, request: AiWeeklyGenerateRequest):
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
        return prompt

    def _resolve_existing(
        self,
        session: Session,
        row: AiGenerationRequest,
        *,
        request: AiWeeklyGenerateRequest,
        user_id: str,
        now: int,
    ) -> AiWeeklyGenerateResponse | AiRequestStatusResponse:
        if (
            row.input_hash != request.input_hash
            or row.report_type != request.payload.report_type
            or row.prompt_version != request.payload.prompt_version
        ):
            log_ai_event(
                "ai_request_conflict",
                environment=self.settings.environment,
                user_id=user_id,
                request_id=row.request_id,
                input_hash=request.input_hash,
                status=row.status,
                error_code="idempotency_conflict",
            )
            raise IdempotencyConflictError()
        row = self.ledger.normalize_existing(session, row, now=now)
        if row.status == "completed":
            log_ai_event(
                "ai_request_replayed",
                environment=self.settings.environment,
                user_id=user_id,
                request_id=row.request_id,
                input_hash=row.input_hash,
                provider=row.provider,
                model=row.model,
                status=(
                    "result_expired"
                    if row.result_purged_at is not None
                    else "completed"
                ),
            )
            return self.ledger.replay_completed(row)
        if row.status == "failed":
            code = row.error_code or "request_failed"
            log_ai_event(
                "ai_request_replayed",
                environment=self.settings.environment,
                user_id=user_id,
                request_id=row.request_id,
                input_hash=row.input_hash,
                provider=row.provider,
                model=row.model,
                status="failed",
                error_code=code,
            )
            raise AiGatewayError(code, status_code=_failure_status(code))
        if row.status == "outcome_unknown":
            log_ai_event(
                "ai_request_outcome_unknown",
                environment=self.settings.environment,
                user_id=user_id,
                request_id=row.request_id,
                input_hash=row.input_hash,
                status="outcome_unknown",
                error_code="outcome_unknown",
            )
            raise AiGatewayError("outcome_unknown", status_code=409)
        log_ai_event(
            "ai_request_processing",
            environment=self.settings.environment,
            user_id=user_id,
            request_id=row.request_id,
            input_hash=row.input_hash,
            status="processing",
        )
        return self.ledger.status_response(row)


def _failure_status(code: str) -> int:
    return {
        "provider_rate_limited": 429,
        "provider_timeout": 504,
        "provider_unavailable": 503,
        "provider_refused": 422,
        "result_expired": 410,
    }.get(code, 502)


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
