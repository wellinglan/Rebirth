from __future__ import annotations

import json
import uuid
from dataclasses import dataclass

from sqlalchemy import delete, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.ai.errors import AiGatewayError
from app.ai.schemas import (
    AiRequestStatusResponse,
    AiWeeklyGenerateRequest,
    AiWeeklyGenerateResponse,
    AiWeeklyStructuredOutput,
)
from app.config import Settings
from app.models import AiGenerationRequest


_HOUR_MS = 60 * 60 * 1000
_DAY_MS = 24 * _HOUR_MS
_MINUTE_MS = 60 * 1000


@dataclass(frozen=True)
class LedgerClaim:
    row: AiGenerationRequest
    owns_provider_call: bool


class AiRequestLedger:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def cleanup(self, session: Session, *, now: int) -> None:
        session.execute(
            update(AiGenerationRequest)
            .where(
                AiGenerationRequest.status == "completed",
                AiGenerationRequest.result_expires_at.is_not(None),
                AiGenerationRequest.result_expires_at <= now,
                AiGenerationRequest.result_purged_at.is_(None),
            )
            .values(
                report_content=None,
                structured_output_json=None,
                result_purged_at=now,
                updated_at=now,
            )
        )
        session.execute(
            delete(AiGenerationRequest).where(
                AiGenerationRequest.dedupe_expires_at <= now
            )
        )
        session.commit()

    def find(
        self, session: Session, *, user_id: str, request_id: str
    ) -> AiGenerationRequest | None:
        return session.scalar(
            select(AiGenerationRequest).where(
                AiGenerationRequest.user_id == user_id,
                AiGenerationRequest.request_id == request_id,
            )
        )

    def claim(
        self,
        session: Session,
        *,
        user_id: str,
        request: AiWeeklyGenerateRequest,
        now: int,
    ) -> LedgerClaim:
        row = AiGenerationRequest(
            id=str(uuid.uuid4()),
            user_id=user_id,
            request_id=str(request.request_id),
            input_hash=request.input_hash,
            report_type=request.payload.report_type,
            prompt_version=request.payload.prompt_version,
            status="processing",
            provider=None,
            model=None,
            output_schema_version=None,
            report_content=None,
            structured_output_json=None,
            error_code=None,
            created_at=now,
            updated_at=now,
            lease_expires_at=(
                now + self._settings.ai_processing_lease_minutes * _MINUTE_MS
            ),
            result_expires_at=None,
            dedupe_expires_at=(
                now + self._settings.ai_dedupe_retention_days * _DAY_MS
            ),
            result_purged_at=None,
        )
        session.add(row)
        try:
            session.commit()
            return LedgerClaim(row=row, owns_provider_call=True)
        except IntegrityError:
            session.rollback()
            existing = self.find(
                session,
                user_id=user_id,
                request_id=str(request.request_id),
            )
            if existing is None:
                raise AiGatewayError("request_failed") from None
            return LedgerClaim(row=existing, owns_provider_call=False)

    def normalize_existing(
        self, session: Session, row: AiGenerationRequest, *, now: int
    ) -> AiGenerationRequest:
        if (
            row.status == "completed"
            and row.result_expires_at is not None
            and row.result_expires_at <= now
            and row.result_purged_at is None
        ):
            row.report_content = None
            row.structured_output_json = None
            row.result_purged_at = now
            row.updated_at = now
            session.commit()
        if (
            row.status == "processing"
            and row.lease_expires_at is not None
            and row.lease_expires_at <= now
        ):
            changed = session.execute(
                update(AiGenerationRequest)
                .where(
                    AiGenerationRequest.id == row.id,
                    AiGenerationRequest.status == "processing",
                    AiGenerationRequest.lease_expires_at <= now,
                )
                .values(status="outcome_unknown", updated_at=now)
            ).rowcount
            session.commit()
            if changed:
                row.status = "outcome_unknown"
                row.updated_at = now
            else:
                session.refresh(row)
        return row

    def mark_completed(
        self,
        session: Session,
        row: AiGenerationRequest,
        result: AiWeeklyGenerateResponse,
        *,
        now: int,
    ) -> None:
        structured_json = json.dumps(
            result.structured_output.model_dump(mode="json"),
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        )
        try:
            changed = session.execute(
                update(AiGenerationRequest)
                .where(
                    AiGenerationRequest.id == row.id,
                    AiGenerationRequest.status == "processing",
                )
                .values(
                    status="completed",
                    provider=result.provider,
                    model=result.model,
                    output_schema_version=result.output_schema_version,
                    report_content=result.report_content,
                    structured_output_json=structured_json,
                    error_code=None,
                    updated_at=now,
                    lease_expires_at=None,
                    result_expires_at=(
                        now
                        + self._settings.ai_result_retention_hours * _HOUR_MS
                    ),
                    dedupe_expires_at=(
                        now + self._settings.ai_dedupe_retention_days * _DAY_MS
                    ),
                )
            ).rowcount
            if changed != 1:
                raise RuntimeError("AI ledger ownership was lost.")
            session.commit()
        except Exception:
            session.rollback()
            raise AiGatewayError("request_failed") from None

    def mark_failed(
        self,
        session: Session,
        row: AiGenerationRequest,
        error: AiGatewayError,
        *,
        provider: str | None,
        model: str | None,
        now: int,
    ) -> None:
        try:
            changed = session.execute(
                update(AiGenerationRequest)
                .where(
                    AiGenerationRequest.id == row.id,
                    AiGenerationRequest.status == "processing",
                )
                .values(
                    status="failed",
                    provider=provider,
                    model=model,
                    error_code=error.code,
                    updated_at=now,
                    lease_expires_at=None,
                    dedupe_expires_at=(
                        now + self._settings.ai_dedupe_retention_days * _DAY_MS
                    ),
                )
            ).rowcount
            if changed != 1:
                raise RuntimeError("AI ledger ownership was lost.")
            session.commit()
        except Exception:
            session.rollback()
            raise AiGatewayError("request_failed") from None

    def replay_completed(
        self, row: AiGenerationRequest
    ) -> AiWeeklyGenerateResponse:
        if (
            row.result_purged_at is not None
            or row.report_content is None
            or row.structured_output_json is None
        ):
            raise AiGatewayError("result_expired", status_code=410)
        try:
            structured = AiWeeklyStructuredOutput.model_validate_json(
                row.structured_output_json
            )
        except Exception:
            raise AiGatewayError("response_invalid") from None
        return AiWeeklyGenerateResponse(
            request_id=row.request_id,
            input_hash=row.input_hash,
            provider=row.provider or "unknown",
            model=row.model or "unknown",
            output_schema_version=row.output_schema_version or 1,
            report_content=row.report_content,
            structured_output=structured,
        )

    def status_response(
        self, row: AiGenerationRequest
    ) -> AiRequestStatusResponse:
        status = row.status
        structured = None
        content = None
        note = None
        if status == "completed":
            if (
                row.result_purged_at is not None
                or row.report_content is None
                or row.structured_output_json is None
            ):
                status = "result_expired"
            else:
                content = row.report_content
                try:
                    structured = AiWeeklyStructuredOutput.model_validate_json(
                        row.structured_output_json
                    )
                except Exception:
                    raise AiGatewayError("response_invalid") from None
        if status == "outcome_unknown":
            note = (
                "The server cannot determine whether the provider produced "
                "a result or incurred cost. This request_id will not be retried."
            )
        return AiRequestStatusResponse(
            request_id=row.request_id,
            input_hash=row.input_hash,
            report_type=row.report_type,
            prompt_version=row.prompt_version,
            status=status,
            provider=row.provider,
            model=row.model,
            output_schema_version=row.output_schema_version,
            report_content=content,
            structured_output=structured,
            error_code=row.error_code,
            created_at=row.created_at,
            lease_expires_at=row.lease_expires_at,
            result_expires_at=row.result_expires_at,
            outcome_note=note,
        )
