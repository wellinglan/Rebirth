from __future__ import annotations

import json
from collections import Counter, defaultdict
from typing import Callable

from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.ai.prompts import PROMPT_REGISTRY
from app.ai.schemas import (
    AiReportFeedbackDeleteRequest,
    AiReportFeedbackItem,
    AiReportFeedbackMutationResponse,
    AiReportFeedbackWriteRequest,
)
from app.ai.service import utc_milliseconds
from app.models import AiReportFeedback, SyncItem


class AiReportFeedbackError(Exception):
    def __init__(self, code: str, status_code: int) -> None:
        super().__init__(code)
        self.code = code
        self.status_code = status_code


class AiReportFeedbackService:
    def __init__(self, clock: Callable[[], int] = utc_milliseconds) -> None:
        self._clock = clock

    def list_for_user(
        self, session: Session, *, user_id: str
    ) -> list[AiReportFeedbackItem]:
        rows = session.scalars(
            select(AiReportFeedback)
            .where(AiReportFeedback.cloud_user_id == user_id)
            .order_by(
                AiReportFeedback.report_record_id,
                AiReportFeedback.report_version_number,
            )
        ).all()
        return [self._item(row) for row in rows]

    def write(
        self,
        session: Session,
        *,
        user_id: str,
        request: AiReportFeedbackWriteRequest,
    ) -> AiReportFeedbackMutationResponse:
        self._validate_report_version(
            session,
            user_id=user_id,
            report_id=str(request.report_id),
            report_version=request.report_version,
            report_type=request.report_type,
        )
        if PROMPT_REGISTRY.get(request.prompt_id, request.prompt_version) is None:
            raise AiReportFeedbackError("prompt_not_supported", 422)
        current = self._find(
            session,
            user_id=user_id,
            report_id=str(request.report_id),
            report_version=request.report_version,
        )
        reasons = json.dumps(
            request.reason_codes,
            separators=(",", ":"),
            sort_keys=True,
        )
        if current is None:
            if request.expected_server_version is not None:
                raise AiReportFeedbackError("feedback_not_found", 409)
            now = self._clock()
            row = AiReportFeedback(
                id=str(request.feedback_id),
                cloud_user_id=user_id,
                report_record_id=str(request.report_id),
                report_version_number=request.report_version,
                report_type=request.report_type,
                helpfulness=request.helpfulness,
                reason_codes_json=reasons,
                prompt_id=request.prompt_id,
                prompt_version=request.prompt_version,
                server_version=1,
                created_at=now,
                updated_at=now,
                deleted_at=None,
            )
            session.add(row)
            try:
                session.commit()
            except IntegrityError:
                session.rollback()
                latest = self._find(
                    session,
                    user_id=user_id,
                    report_id=str(request.report_id),
                    report_version=request.report_version,
                )
                if latest is None:
                    raise AiReportFeedbackError("feedback_id_conflict", 409)
                same = (
                    latest.id == str(request.feedback_id)
                    and latest.helpfulness == request.helpfulness
                    and latest.reason_codes_json == reasons
                    and latest.prompt_id == request.prompt_id
                    and latest.prompt_version == request.prompt_version
                    and latest.deleted_at is None
                )
                return AiReportFeedbackMutationResponse(
                    outcome="applied" if same else "conflict",
                    item=self._item(latest),
                )
            return AiReportFeedbackMutationResponse(
                outcome="applied", item=self._item(row)
            )
        same = (
            current.id == str(request.feedback_id)
            and current.helpfulness == request.helpfulness
            and current.reason_codes_json == reasons
            and current.prompt_id == request.prompt_id
            and current.prompt_version == request.prompt_version
            and current.deleted_at is None
        )
        if same:
            return AiReportFeedbackMutationResponse(
                outcome="applied", item=self._item(current)
            )
        if request.expected_server_version != current.server_version:
            return AiReportFeedbackMutationResponse(
                outcome="conflict", item=self._item(current)
            )
        now = self._clock()
        changed = session.execute(
            update(AiReportFeedback)
            .where(
                AiReportFeedback.id == current.id,
                AiReportFeedback.cloud_user_id == user_id,
                AiReportFeedback.server_version == current.server_version,
            )
            .values(
                helpfulness=request.helpfulness,
                reason_codes_json=reasons,
                prompt_id=request.prompt_id,
                prompt_version=request.prompt_version,
                server_version=current.server_version + 1,
                updated_at=now,
                deleted_at=None,
            )
        ).rowcount
        if changed != 1:
            session.rollback()
            latest = self._require_current(
                session,
                user_id=user_id,
                report_id=str(request.report_id),
                report_version=request.report_version,
            )
            return AiReportFeedbackMutationResponse(
                outcome="conflict", item=self._item(latest)
            )
        session.commit()
        updated = self._require_current(
            session,
            user_id=user_id,
            report_id=str(request.report_id),
            report_version=request.report_version,
        )
        return AiReportFeedbackMutationResponse(
            outcome="applied", item=self._item(updated)
        )

    def delete(
        self,
        session: Session,
        *,
        user_id: str,
        request: AiReportFeedbackDeleteRequest,
    ) -> AiReportFeedbackMutationResponse:
        current = self._find(
            session,
            user_id=user_id,
            report_id=str(request.report_id),
            report_version=request.report_version,
        )
        if current is None or current.id != str(request.feedback_id):
            raise AiReportFeedbackError("feedback_not_found", 404)
        if current.deleted_at is not None:
            return AiReportFeedbackMutationResponse(
                outcome="applied", item=self._item(current)
            )
        if request.expected_server_version != current.server_version:
            return AiReportFeedbackMutationResponse(
                outcome="conflict", item=self._item(current)
            )
        now = self._clock()
        changed = session.execute(
            update(AiReportFeedback)
            .where(
                AiReportFeedback.id == current.id,
                AiReportFeedback.cloud_user_id == user_id,
                AiReportFeedback.server_version == current.server_version,
            )
            .values(
                server_version=current.server_version + 1,
                updated_at=now,
                deleted_at=now,
            )
        ).rowcount
        if changed != 1:
            session.rollback()
            latest = self._require_current(
                session,
                user_id=user_id,
                report_id=str(request.report_id),
                report_version=request.report_version,
            )
            return AiReportFeedbackMutationResponse(
                outcome="conflict", item=self._item(latest)
            )
        session.commit()
        updated = self._require_current(
            session,
            user_id=user_id,
            report_id=str(request.report_id),
            report_version=request.report_version,
        )
        return AiReportFeedbackMutationResponse(
            outcome="applied", item=self._item(updated)
        )

    def _validate_report_version(
        self,
        session: Session,
        *,
        user_id: str,
        report_id: str,
        report_version: int,
        report_type: str | None = None,
    ) -> None:
        report = session.scalar(
            select(SyncItem).where(
                SyncItem.user_id == user_id,
                SyncItem.table_name == "ai_reports",
                SyncItem.record_id == report_id,
                SyncItem.deleted_at.is_(None),
            )
        )
        if report is None:
            raise AiReportFeedbackError("report_not_synced", 409)
        try:
            payload = json.loads(report.payload_json)
            if report_type is not None and payload["report_type"] != report_type:
                raise KeyError
            version = next(
                item
                for item in payload["versions"]
                if item["version"] == report_version
            )
            if version["status"] != "completed" or not version.get("content"):
                raise KeyError
        except (KeyError, TypeError, ValueError, StopIteration, json.JSONDecodeError):
            raise AiReportFeedbackError("report_version_not_eligible", 422)

    def _find(
        self,
        session: Session,
        *,
        user_id: str,
        report_id: str,
        report_version: int,
    ) -> AiReportFeedback | None:
        return session.scalar(
            select(AiReportFeedback).where(
                AiReportFeedback.cloud_user_id == user_id,
                AiReportFeedback.report_record_id == report_id,
                AiReportFeedback.report_version_number == report_version,
            )
        )

    def _require_current(self, session: Session, **kwargs: object) -> AiReportFeedback:
        row = self._find(session, **kwargs)
        if row is None:
            raise AiReportFeedbackError("feedback_not_found", 404)
        return row

    def _item(self, row: AiReportFeedback) -> AiReportFeedbackItem:
        return AiReportFeedbackItem(
            feedback_id=row.id,
            report_id=row.report_record_id,
            report_version=row.report_version_number,
            report_type=row.report_type,
            helpfulness=row.helpfulness,
            reason_codes=json.loads(row.reason_codes_json),
            prompt_id=row.prompt_id,
            prompt_version=row.prompt_version,
            server_version=row.server_version,
            created_at=row.created_at,
            updated_at=row.updated_at,
            deleted_at=row.deleted_at,
        )


def feedback_audit(
    session: Session,
    *,
    days: int = 30,
    now: int | None = None,
) -> dict[str, object]:
    if days <= 0:
        raise ValueError("days must be positive")
    effective_now = utc_milliseconds() if now is None else now
    start = effective_now - days * 24 * 60 * 60 * 1000
    rows = session.scalars(
        select(AiReportFeedback).where(AiReportFeedback.updated_at >= start)
    ).all()
    grouped: dict[tuple[str, str, str], list[AiReportFeedback]] = defaultdict(list)
    deleted_count = 0
    for row in rows:
        if row.deleted_at is not None:
            deleted_count += 1
            continue
        grouped[(row.report_type, row.prompt_id, row.prompt_version)].append(row)
    groups: list[dict[str, object]] = []
    for (report_type, prompt_id, prompt_version), items in sorted(grouped.items()):
        helpful = sum(item.helpfulness == "helpful" for item in items)
        reason_counts: Counter[str] = Counter()
        for item in items:
            reason_counts.update(json.loads(item.reason_codes_json))
        groups.append(
            {
                "report_type": report_type,
                "prompt_id": prompt_id,
                "prompt_version": prompt_version,
                "sample_size": len(items),
                "helpful_count": helpful,
                "not_helpful_count": len(items) - helpful,
                "helpful_rate": round(helpful / len(items), 4),
                "reason_counts": dict(sorted(reason_counts.items())),
            }
        )
    return {
        "status": "ok",
        "read_only": True,
        "window_days": days,
        "active_sample_size": sum(len(items) for items in grouped.values()),
        "deleted_count": deleted_count,
        "groups": groups,
    }
