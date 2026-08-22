from __future__ import annotations

import uuid
from dataclasses import dataclass

from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.ai.errors import UsageLimitReachedError
from app.config import Settings
from app.models import AiUsageControl, AiUsageRecord


_DAY_MS = 24 * 60 * 60 * 1000
_MINUTE_MS = 60 * 1000
_CONTROL_ROW_ID = 1
_CHAT_REQUEST_TYPE = "coach_chat"


@dataclass(frozen=True)
class AiUsageReservation:
    record_id: str
    reserved_tokens: int


@dataclass(frozen=True)
class AiUsageSnapshot:
    status: str
    enabled: bool
    daily_limit: int
    used: int
    remaining: int
    resets_at: int


@dataclass(frozen=True)
class AiTokenBudgetSnapshot:
    status: str
    unit: str
    limit: int
    used: int
    reserved: int
    remaining: int


@dataclass(frozen=True)
class AiUsageV2Snapshot:
    enabled: bool
    resets_at: int
    chat: AiTokenBudgetSnapshot
    reports: AiTokenBudgetSnapshot


class AiUsageGuard:
    """Atomically reserves and settles token capacity without AI content."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def reserve(
        self,
        session: Session,
        *,
        user_id: str,
        request_id: str,
        provider: str,
        model: str,
        request_type: str,
        now: int,
        estimated_tokens: int = 1,
    ) -> AiUsageReservation:
        if (
            estimated_tokens <= 0
            or estimated_tokens > self._settings.ai_max_request_tokens
        ):
            raise UsageLimitReachedError()
        self._ensure_control_row(session, now=now)
        control = session.scalar(
            select(AiUsageControl)
            .where(AiUsageControl.id == _CONTROL_ROW_ID)
            .with_for_update()
        )
        if control is None:
            session.rollback()
            raise RuntimeError("AI usage control row is unavailable.")

        self._expire_stale_reservations(session, now=now)
        day_start, day_end = _utc_day(now)
        active_count = self._count(
            session,
            AiUsageRecord.status == "processing",
            AiUsageRecord.lease_expires_at > now,
        )
        global_tokens = self._token_total(
            session,
            AiUsageRecord.created_at >= day_start,
            AiUsageRecord.created_at < day_end,
        )
        scope_is_chat = request_type == _CHAT_REQUEST_TYPE
        scope_filter = (
            AiUsageRecord.request_type == _CHAT_REQUEST_TYPE
            if scope_is_chat
            else AiUsageRecord.request_type != _CHAT_REQUEST_TYPE
        )
        user_tokens = self._token_total(
            session,
            AiUsageRecord.user_id == user_id,
            scope_filter,
            AiUsageRecord.created_at >= day_start,
            AiUsageRecord.created_at < day_end,
        )
        scope_limit = (
            self._settings.ai_chat_daily_token_limit
            if scope_is_chat
            else self._settings.ai_report_daily_token_limit
        )
        report_count_limited = False
        report_global_count_limited = False
        if not scope_is_chat:
            report_count_limited = self._count(
                session,
                AiUsageRecord.user_id == user_id,
                AiUsageRecord.request_type != _CHAT_REQUEST_TYPE,
                AiUsageRecord.created_at >= day_start,
                AiUsageRecord.created_at < day_end,
            ) >= self._settings.ai_daily_user_limit
            report_global_count_limited = self._count(
                session,
                AiUsageRecord.request_type != _CHAT_REQUEST_TYPE,
                AiUsageRecord.created_at >= day_start,
                AiUsageRecord.created_at < day_end,
            ) >= self._settings.ai_daily_global_limit
        if (
            report_count_limited
            or report_global_count_limited
            or user_tokens + estimated_tokens > scope_limit
            or global_tokens + estimated_tokens
            > self._settings.ai_daily_global_token_limit
            or active_count >= self._settings.ai_max_concurrent_requests
        ):
            session.rollback()
            raise UsageLimitReachedError()

        record = AiUsageRecord(
            id=str(uuid.uuid4()),
            user_id=user_id,
            request_id=request_id,
            provider=provider,
            model=model,
            request_type=request_type,
            input_tokens=None,
            output_tokens=None,
            total_tokens=None,
            reserved_tokens=estimated_tokens,
            charged_tokens=0,
            accounting_source="reserved_estimate",
            status="processing",
            created_at=now,
            updated_at=now,
            lease_expires_at=(
                now + self._settings.ai_processing_lease_minutes * _MINUTE_MS
            ),
            completed_at=None,
        )
        control.updated_at = now
        session.add(record)
        try:
            session.commit()
        except IntegrityError:
            session.rollback()
            raise UsageLimitReachedError() from None
        return AiUsageReservation(
            record_id=record.id,
            reserved_tokens=estimated_tokens,
        )

    def snapshot(
        self,
        session: Session,
        *,
        user_id: str,
        provider_enabled: bool,
        now: int,
    ) -> AiUsageSnapshot:
        """Legacy report-count view retained for old clients."""
        day_start, day_end = _utc_day(now)
        criteria = (
            AiUsageRecord.request_type != _CHAT_REQUEST_TYPE,
            AiUsageRecord.created_at >= day_start,
            AiUsageRecord.created_at < day_end,
        )
        user_count = self._count(
            session, AiUsageRecord.user_id == user_id, *criteria
        )
        global_count = self._count(session, *criteria)
        active_count = self._count(
            session,
            AiUsageRecord.status == "processing",
            AiUsageRecord.lease_expires_at > now,
        )
        remaining = max(self._settings.ai_daily_user_limit - user_count, 0)
        if not provider_enabled:
            status = "disabled"
        elif (
            remaining == 0
            or global_count >= self._settings.ai_daily_global_limit
            or active_count >= self._settings.ai_max_concurrent_requests
        ):
            status = "limit_reached"
        else:
            status = "available"
        return AiUsageSnapshot(
            status=status,
            enabled=provider_enabled,
            daily_limit=self._settings.ai_daily_user_limit,
            used=user_count,
            remaining=remaining,
            resets_at=day_end,
        )

    def snapshot_v2(
        self,
        session: Session,
        *,
        user_id: str,
        provider_enabled: bool,
        now: int,
    ) -> AiUsageV2Snapshot:
        self._ensure_control_row(session, now=now)
        self._expire_stale_reservations(session, now=now)
        session.commit()
        day_start, day_end = _utc_day(now)
        active_count = self._count(
            session,
            AiUsageRecord.status == "processing",
            AiUsageRecord.lease_expires_at > now,
        )
        global_tokens = self._token_total(
            session,
            AiUsageRecord.created_at >= day_start,
            AiUsageRecord.created_at < day_end,
        )
        globally_available = (
            global_tokens < self._settings.ai_daily_global_token_limit
            and active_count < self._settings.ai_max_concurrent_requests
        )
        report_count_available = (
            self._count(
                session,
                AiUsageRecord.request_type != _CHAT_REQUEST_TYPE,
                AiUsageRecord.created_at >= day_start,
                AiUsageRecord.created_at < day_end,
            )
            < self._settings.ai_daily_global_limit
            and self._count(
                session,
                AiUsageRecord.user_id == user_id,
                AiUsageRecord.request_type != _CHAT_REQUEST_TYPE,
                AiUsageRecord.created_at >= day_start,
                AiUsageRecord.created_at < day_end,
            )
            < self._settings.ai_daily_user_limit
        )
        return AiUsageV2Snapshot(
            enabled=provider_enabled,
            resets_at=day_end,
            chat=self._budget_snapshot(
                session,
                user_id=user_id,
                request_type_is_chat=True,
                limit=self._settings.ai_chat_daily_token_limit,
                provider_enabled=provider_enabled,
                globally_available=globally_available,
                day_start=day_start,
                day_end=day_end,
            ),
            reports=self._budget_snapshot(
                session,
                user_id=user_id,
                request_type_is_chat=False,
                limit=self._settings.ai_report_daily_token_limit,
                provider_enabled=provider_enabled,
                globally_available=(
                    globally_available and report_count_available
                ),
                day_start=day_start,
                day_end=day_end,
            ),
        )

    def mark_completed(
        self,
        session: Session,
        reservation: AiUsageReservation,
        *,
        model: str,
        input_tokens: int | None,
        output_tokens: int | None,
        total_tokens: int | None,
        now: int,
    ) -> None:
        actual, source = _settled_tokens(
            reservation,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            total_tokens=total_tokens,
        )
        self._finish(
            session,
            reservation,
            status="completed",
            model=model,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            total_tokens=total_tokens,
            charged_tokens=actual,
            accounting_source=source,
            now=now,
        )

    def mark_failed(
        self,
        session: Session,
        reservation: AiUsageReservation,
        *,
        now: int,
    ) -> None:
        self._finish(
            session,
            reservation,
            status="failed",
            charged_tokens=reservation.reserved_tokens,
            accounting_source="fallback_estimate",
            now=now,
        )

    def hold_unknown(
        self,
        session: Session,
        reservation: AiUsageReservation,
        *,
        now: int,
    ) -> None:
        changed = session.execute(
            update(AiUsageRecord)
            .where(
                AiUsageRecord.id == reservation.record_id,
                AiUsageRecord.status == "processing",
            )
            .values(updated_at=now, accounting_source="outcome_unknown_hold")
        ).rowcount
        if changed != 1:
            session.rollback()
            raise RuntimeError("AI usage reservation is not active.")
        session.commit()

    def release(
        self,
        session: Session,
        reservation: AiUsageReservation,
        *,
        now: int,
    ) -> None:
        self._finish(
            session,
            reservation,
            status="failed",
            charged_tokens=0,
            accounting_source="released_before_provider",
            now=now,
        )

    def _finish(
        self,
        session: Session,
        reservation: AiUsageReservation,
        *,
        status: str,
        charged_tokens: int,
        accounting_source: str,
        now: int,
        model: str | None = None,
        input_tokens: int | None = None,
        output_tokens: int | None = None,
        total_tokens: int | None = None,
    ) -> None:
        values: dict[str, object] = {
            "status": status,
            "reserved_tokens": 0,
            "charged_tokens": charged_tokens,
            "accounting_source": accounting_source,
            "updated_at": now,
            "lease_expires_at": None,
            "completed_at": now,
        }
        if model is not None:
            values.update(
                model=model,
                input_tokens=input_tokens,
                output_tokens=output_tokens,
                total_tokens=total_tokens,
            )
        changed = session.execute(
            update(AiUsageRecord)
            .where(
                AiUsageRecord.id == reservation.record_id,
                AiUsageRecord.status == "processing",
            )
            .values(**values)
        ).rowcount
        if changed != 1:
            session.rollback()
            raise RuntimeError("AI usage reservation is not active.")
        session.commit()

    def _budget_snapshot(
        self,
        session: Session,
        *,
        user_id: str,
        request_type_is_chat: bool,
        limit: int,
        provider_enabled: bool,
        globally_available: bool,
        day_start: int,
        day_end: int,
    ) -> AiTokenBudgetSnapshot:
        type_filter = (
            AiUsageRecord.request_type == _CHAT_REQUEST_TYPE
            if request_type_is_chat
            else AiUsageRecord.request_type != _CHAT_REQUEST_TYPE
        )
        criteria = (
            AiUsageRecord.user_id == user_id,
            type_filter,
            AiUsageRecord.created_at >= day_start,
            AiUsageRecord.created_at < day_end,
        )
        used = self._sum(session, AiUsageRecord.charged_tokens, *criteria)
        reserved = self._sum(session, AiUsageRecord.reserved_tokens, *criteria)
        remaining = max(limit - used - reserved, 0)
        if not provider_enabled:
            status = "disabled"
        elif remaining == 0 or not globally_available:
            status = "limit_reached"
        else:
            status = "available"
        return AiTokenBudgetSnapshot(
            status=status,
            unit="tokens",
            limit=limit,
            used=used,
            reserved=reserved,
            remaining=remaining,
        )

    def _expire_stale_reservations(self, session: Session, *, now: int) -> None:
        session.execute(
            update(AiUsageRecord)
            .where(
                AiUsageRecord.status == "processing",
                AiUsageRecord.lease_expires_at.is_not(None),
                AiUsageRecord.lease_expires_at <= now,
            )
            .values(
                status="expired",
                charged_tokens=AiUsageRecord.reserved_tokens,
                reserved_tokens=0,
                accounting_source="lease_expired_fallback",
                updated_at=now,
                completed_at=now,
            )
        )

    def _ensure_control_row(self, session: Session, *, now: int) -> None:
        if session.get(AiUsageControl, _CONTROL_ROW_ID) is not None:
            session.rollback()
            return
        session.add(AiUsageControl(id=_CONTROL_ROW_ID, updated_at=now))
        try:
            session.commit()
        except IntegrityError:
            session.rollback()

    @staticmethod
    def _count(session: Session, *criteria: object) -> int:
        return int(
            session.scalar(
                select(func.count()).select_from(AiUsageRecord).where(*criteria)
            )
            or 0
        )

    @staticmethod
    def _sum(session: Session, column: object, *criteria: object) -> int:
        return int(
            session.scalar(
                select(func.coalesce(func.sum(column), 0))
                .select_from(AiUsageRecord)
                .where(*criteria)
            )
            or 0
        )

    @classmethod
    def _token_total(cls, session: Session, *criteria: object) -> int:
        return cls._sum(
            session,
            AiUsageRecord.charged_tokens + AiUsageRecord.reserved_tokens,
            *criteria,
        )


def _utc_day(now: int) -> tuple[int, int]:
    start = (now // _DAY_MS) * _DAY_MS
    return start, start + _DAY_MS


def _settled_tokens(
    reservation: AiUsageReservation,
    *,
    input_tokens: int | None,
    output_tokens: int | None,
    total_tokens: int | None,
) -> tuple[int, str]:
    if total_tokens is not None and total_tokens >= 0:
        return total_tokens, "provider_total"
    if input_tokens is not None and output_tokens is not None:
        return max(input_tokens, 0) + max(output_tokens, 0), "provider_parts"
    return reservation.reserved_tokens, "fallback_estimate"
