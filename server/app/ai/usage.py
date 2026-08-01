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


@dataclass(frozen=True)
class AiUsageReservation:
    record_id: str


@dataclass(frozen=True)
class AiUsageSnapshot:
    status: str
    enabled: bool
    daily_limit: int
    used: int
    remaining: int
    resets_at: int


class AiUsageGuard:
    """Atomically reserves provider capacity without storing AI content."""

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
    ) -> AiUsageReservation:
        self._ensure_control_row(session, now=now)
        control = session.scalar(
            select(AiUsageControl)
            .where(AiUsageControl.id == _CONTROL_ROW_ID)
            .with_for_update()
        )
        if control is None:
            session.rollback()
            raise RuntimeError("AI usage control row is unavailable.")

        session.execute(
            update(AiUsageRecord)
            .where(
                AiUsageRecord.status == "processing",
                AiUsageRecord.lease_expires_at.is_not(None),
                AiUsageRecord.lease_expires_at <= now,
            )
            .values(status="expired", updated_at=now, completed_at=now)
        )
        day_start = (now // _DAY_MS) * _DAY_MS
        day_end = day_start + _DAY_MS
        global_count = self._count(
            session,
            AiUsageRecord.created_at >= day_start,
            AiUsageRecord.created_at < day_end,
        )
        user_count = self._count(
            session,
            AiUsageRecord.user_id == user_id,
            AiUsageRecord.created_at >= day_start,
            AiUsageRecord.created_at < day_end,
        )
        active_count = self._count(
            session,
            AiUsageRecord.status == "processing",
            AiUsageRecord.lease_expires_at > now,
        )
        if (
            user_count >= self._settings.ai_daily_user_limit
            or global_count >= self._settings.ai_daily_global_limit
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
        return AiUsageReservation(record_id=record.id)

    def snapshot(
        self,
        session: Session,
        *,
        user_id: str,
        provider_enabled: bool,
        now: int,
    ) -> AiUsageSnapshot:
        day_start = (now // _DAY_MS) * _DAY_MS
        day_end = day_start + _DAY_MS
        user_count = self._count(
            session,
            AiUsageRecord.user_id == user_id,
            AiUsageRecord.created_at >= day_start,
            AiUsageRecord.created_at < day_end,
        )
        global_count = self._count(
            session,
            AiUsageRecord.created_at >= day_start,
            AiUsageRecord.created_at < day_end,
        )
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
        self._finish(
            session,
            reservation,
            status="completed",
            model=model,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            total_tokens=total_tokens,
            now=now,
        )

    def mark_failed(
        self,
        session: Session,
        reservation: AiUsageReservation,
        *,
        now: int,
    ) -> None:
        self._finish(session, reservation, status="failed", now=now)

    def _finish(
        self,
        session: Session,
        reservation: AiUsageReservation,
        *,
        status: str,
        now: int,
        model: str | None = None,
        input_tokens: int | None = None,
        output_tokens: int | None = None,
        total_tokens: int | None = None,
    ) -> None:
        values: dict[str, object] = {
            "status": status,
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
