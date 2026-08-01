from __future__ import annotations

import math
from collections import defaultdict
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import and_, func, select
from sqlalchemy.orm import Session

from app.ai.observability import log_ai_event
from app.config import Settings
from app.models import AiGenerationRequest, AiUsageRecord


_DAY_MS = 24 * 60 * 60 * 1000
_LOCAL_REJECTION_CODES = frozenset({"usage_limit_reached"})


def audit_usage(session: Session, *, days: int, now: int) -> dict[str, Any]:
    start = _window_start(days, now)
    rows = session.execute(
        select(
            AiUsageRecord.created_at,
            AiUsageRecord.provider,
            AiUsageRecord.model,
            AiUsageRecord.request_type,
            AiUsageRecord.status,
            AiUsageRecord.input_tokens,
            AiUsageRecord.output_tokens,
            AiUsageRecord.total_tokens,
            AiGenerationRequest.error_code,
        )
        .select_from(AiUsageRecord)
        .outerjoin(
            AiGenerationRequest,
            and_(
                AiGenerationRequest.user_id == AiUsageRecord.user_id,
                AiGenerationRequest.request_id == AiUsageRecord.request_id,
            ),
        )
        .where(
            AiUsageRecord.created_at >= start,
            AiUsageRecord.created_at <= now,
        )
    ).all()
    groups: dict[tuple[str, str, str, str], dict[str, Any]] = {}
    total = _empty_counts()
    for row in rows:
        date = _utc_date(row.created_at)
        key = (date, row.provider, row.model, row.request_type)
        counts = groups.setdefault(
            key,
            {
                "date": date,
                "provider": row.provider,
                "model": row.model,
                "request_type": row.request_type,
                **_empty_counts(),
            },
        )
        _count_usage(counts, row)
        _count_usage(total, row)
    return {
        "status": "ok",
        "generated_at_utc_ms": now,
        "window_start_utc_ms": start,
        "window_end_utc_ms": now,
        "days": days,
        "groups": sorted(
            groups.values(),
            key=lambda item: (
                item["date"],
                item["provider"],
                item["model"],
                item["request_type"],
            ),
        ),
        "totals": total,
    }


def configuration_summary(settings: Settings) -> dict[str, Any]:
    provider_ready = _provider_ready(settings)
    return {
        "status": "ok" if provider_ready else "not_ready",
        "provider": settings.ai_provider,
        "model": settings.ai_model,
        "timeout_seconds": settings.ai_timeout_seconds,
        "max_output_tokens": settings.ai_max_output_tokens,
        "daily_user_limit": settings.ai_daily_user_limit,
        "daily_global_limit": settings.ai_daily_global_limit,
        "monthly_global_alert_limit": settings.ai_monthly_global_limit,
        "budget_warning_percent": settings.ai_budget_warning_percent,
        "enabled": settings.ai_provider != "disabled" and provider_ready,
        "provider_ready": provider_ready,
    }


def monitor_operations(
    session: Session,
    *,
    settings: Settings,
    window_minutes: int,
    now: int,
    emit_logs: bool = True,
) -> dict[str, Any]:
    if window_minutes <= 0:
        raise ValueError("window_minutes must be positive")
    window_start = now - window_minutes * 60 * 1000
    usage_rows = session.execute(
        select(
            AiUsageRecord.provider,
            AiUsageRecord.status,
            AiGenerationRequest.error_code,
        )
        .select_from(AiUsageRecord)
        .outerjoin(
            AiGenerationRequest,
            and_(
                AiGenerationRequest.user_id == AiUsageRecord.user_id,
                AiGenerationRequest.request_id == AiUsageRecord.request_id,
            ),
        )
        .where(
            AiUsageRecord.created_at >= window_start,
            AiUsageRecord.created_at <= now,
        )
    ).all()
    providers: dict[str, dict[str, Any]] = defaultdict(
        lambda: {
            "request_count": 0,
            "failure_count": 0,
            "timeout_count": 0,
            "expired_count": 0,
        }
    )
    for row in usage_rows:
        item = providers[row.provider]
        item["request_count"] += 1
        item["failure_count"] += int(row.status == "failed")
        item["timeout_count"] += int(row.error_code == "provider_timeout")
        item["expired_count"] += int(row.status == "expired")

    events: list[dict[str, Any]] = []
    provider_reports: list[dict[str, Any]] = []
    for provider, counts in sorted(providers.items()):
        request_count = counts["request_count"]
        failure_rate = _percentage(counts["failure_count"], request_count)
        timeout_rate = _percentage(counts["timeout_count"], request_count)
        provider_reports.append(
            {
                "provider": provider,
                **counts,
                "failure_rate_percent": failure_rate,
                "timeout_rate_percent": timeout_rate,
            }
        )
        if failure_rate >= settings.ai_failure_rate_warning_percent:
            events.append(
                _event(
                    "AI_PROVIDER_FAILURE_RATE_HIGH",
                    now,
                    provider,
                    "failure_rate_percent",
                    failure_rate,
                    settings.ai_failure_rate_warning_percent,
                )
            )
        if timeout_rate >= settings.ai_timeout_rate_warning_percent:
            events.append(
                _event(
                    "AI_PROVIDER_TIMEOUT_RATE_HIGH",
                    now,
                    provider,
                    "timeout_rate_percent",
                    timeout_rate,
                    settings.ai_timeout_rate_warning_percent,
                )
            )
        if counts["expired_count"]:
            events.append(
                _event(
                    "AI_EXPIRED_GENERATION_DETECTED",
                    now,
                    provider,
                    "expired_count",
                    counts["expired_count"],
                    1,
                )
            )

    stale_usage = session.execute(
        select(AiUsageRecord.user_id, AiUsageRecord.request_id).where(
            AiUsageRecord.status == "processing",
            AiUsageRecord.lease_expires_at.is_not(None),
            AiUsageRecord.lease_expires_at <= now,
        )
    ).all()
    stale_generations = session.execute(
        select(
            AiGenerationRequest.user_id,
            AiGenerationRequest.request_id,
        ).where(
            AiGenerationRequest.status == "processing",
            AiGenerationRequest.lease_expires_at.is_not(None),
            AiGenerationRequest.lease_expires_at <= now,
        )
    ).all()
    backlog_keys = {
        (row.user_id, row.request_id)
        for row in [*stale_usage, *stale_generations]
    }
    backlog = len(backlog_keys)
    if backlog >= settings.ai_processing_backlog_warning:
        events.append(
            _event(
                "AI_PROCESSING_LEASE_BACKLOG",
                now,
                settings.ai_provider,
                "stale_processing_lease_count",
                backlog,
                settings.ai_processing_backlog_warning,
            )
        )

    day_start = (now // _DAY_MS) * _DAY_MS
    month_start = _utc_month_start(now)
    daily_count = _usage_count(session, day_start, now)
    monthly_count = _usage_count(session, month_start, now)
    _append_budget_event(
        events,
        now=now,
        provider=settings.ai_provider,
        metric="daily_global_request_count",
        value=daily_count,
        limit=settings.ai_daily_global_limit,
        warning_percent=settings.ai_budget_warning_percent,
    )
    _append_budget_event(
        events,
        now=now,
        provider=settings.ai_provider,
        metric="monthly_global_request_count",
        value=monthly_count,
        limit=settings.ai_monthly_global_limit,
        warning_percent=settings.ai_budget_warning_percent,
    )
    if emit_logs:
        for item in events:
            log_ai_event(
                item["event"],
                environment=settings.environment,
                timestamp=item["timestamp"],
                provider=item["provider"],
                metric=item["metric"],
                value=item["value"],
                threshold=item["threshold"],
                severity=item["severity"],
            )
    return {
        "status": "warning" if events else "ok",
        "generated_at_utc_ms": now,
        "window_start_utc_ms": window_start,
        "window_end_utc_ms": now,
        "window_minutes": window_minutes,
        "providers": provider_reports,
        "budget": {
            "daily_global_request_count": daily_count,
            "daily_global_limit": settings.ai_daily_global_limit,
            "monthly_global_request_count": monthly_count,
            "monthly_global_alert_limit": settings.ai_monthly_global_limit,
        },
        "processing_lease_backlog": backlog,
        "processing_lease_backlog_sources": {
            "generation_count": len(stale_generations),
            "usage_count": len(stale_usage),
        },
        "events": events,
    }


def check_ledger_consistency(
    session: Session, *, days: int, now: int
) -> dict[str, Any]:
    start = _window_start(days, now)
    generation_links = session.execute(
        select(
            AiGenerationRequest.id.label("generation_id"),
            AiGenerationRequest.status,
            AiGenerationRequest.error_code,
            AiUsageRecord.id.label("usage_id"),
        )
        .select_from(AiGenerationRequest)
        .outerjoin(
            AiUsageRecord,
            and_(
                AiUsageRecord.user_id == AiGenerationRequest.user_id,
                AiUsageRecord.request_id == AiGenerationRequest.request_id,
            ),
        )
        .where(
            AiGenerationRequest.created_at >= start,
            AiGenerationRequest.created_at <= now,
        )
    ).all()
    usage_links = session.execute(
        select(
            AiUsageRecord.id.label("usage_id"),
            AiUsageRecord.status.label("usage_status"),
            AiUsageRecord.input_tokens,
            AiUsageRecord.output_tokens,
            AiUsageRecord.total_tokens,
            AiGenerationRequest.id.label("generation_id"),
            AiGenerationRequest.status.label("generation_status"),
        )
        .select_from(AiUsageRecord)
        .outerjoin(
            AiGenerationRequest,
            and_(
                AiGenerationRequest.user_id == AiUsageRecord.user_id,
                AiGenerationRequest.request_id == AiUsageRecord.request_id,
            ),
        )
        .where(
            AiUsageRecord.created_at >= start,
            AiUsageRecord.created_at <= now,
        )
    ).all()
    generations: dict[str, Any] = {}
    usage_ids_by_generation: dict[str, set[str]] = defaultdict(set)
    for row in generation_links:
        generations[row.generation_id] = row
        if row.usage_id is not None:
            usage_ids_by_generation[row.generation_id].add(row.usage_id)
    missing_usage = 0
    for generation_id, generation in generations.items():
        expects_usage = not (
            generation.status == "failed"
            and generation.error_code in _LOCAL_REJECTION_CODES
        )
        if expects_usage and not usage_ids_by_generation[generation_id]:
            missing_usage += 1
    orphan_usage = sum(row.generation_id is None for row in usage_links)
    duplicate_usage = sum(
        max(len(usage_ids) - 1, 0)
        for usage_ids in usage_ids_by_generation.values()
    )
    token_mismatch = 0
    status_mismatch = 0
    failed_mismatch = 0
    expired_mismatch = 0
    for usage in usage_links:
        if (
            usage.input_tokens is not None
            and usage.output_tokens is not None
            and usage.total_tokens is not None
            and usage.input_tokens + usage.output_tokens != usage.total_tokens
        ):
            token_mismatch += 1
        if usage.generation_id is None:
            continue
        compatible = _statuses_compatible(
            usage.generation_status, usage.usage_status
        )
        status_mismatch += int(not compatible)
        failed_mismatch += int(
            (usage.generation_status == "failed")
            != (usage.usage_status == "failed")
            and usage.usage_status != "expired"
        )
        expired_mismatch += int(
            usage.usage_status == "expired"
            and usage.generation_status not in {"processing", "outcome_unknown"}
        )

    anomalies = {
        "generation_without_usage_count": missing_usage,
        "usage_without_generation_count": orphan_usage,
        "duplicate_usage_count": duplicate_usage,
        "token_total_mismatch_count": token_mismatch,
        "status_mismatch_count": status_mismatch,
        "failed_state_mismatch_count": failed_mismatch,
        "expired_state_mismatch_count": expired_mismatch,
    }
    generation_statuses = _status_counts(generations.values())
    usage_statuses = _status_counts(usage_links, attribute="usage_status")
    return {
        "status": "ok" if not any(anomalies.values()) else "inconsistent",
        "read_only": True,
        "generated_at_utc_ms": now,
        "window_start_utc_ms": start,
        "window_end_utc_ms": now,
        "days": days,
        "generation_count": len(generations),
        "usage_count": len(usage_links),
        "generation_statuses": generation_statuses,
        "usage_statuses": usage_statuses,
        "token_aggregation": {
            "input_tokens": sum(row.input_tokens or 0 for row in usage_links),
            "output_tokens": sum(row.output_tokens or 0 for row in usage_links),
            "total_tokens": sum(row.total_tokens or 0 for row in usage_links),
        },
        "anomalies": anomalies,
    }


def _empty_counts() -> dict[str, int]:
    return {
        "request_count": 0,
        "success_count": 0,
        "failure_count": 0,
        "timeout_count": 0,
        "expired_count": 0,
        "token_input": 0,
        "token_output": 0,
        "token_total": 0,
    }


def _count_usage(counts: dict[str, Any], row: Any) -> None:
    counts["request_count"] += 1
    counts["success_count"] += int(row.status == "completed")
    counts["failure_count"] += int(row.status == "failed")
    counts["timeout_count"] += int(row.error_code == "provider_timeout")
    counts["expired_count"] += int(row.status == "expired")
    counts["token_input"] += row.input_tokens or 0
    counts["token_output"] += row.output_tokens or 0
    counts["token_total"] += row.total_tokens or 0


def _window_start(days: int, now: int) -> int:
    if days <= 0:
        raise ValueError("days must be positive")
    return (now // _DAY_MS - days + 1) * _DAY_MS


def _utc_date(milliseconds: int) -> str:
    return datetime.fromtimestamp(
        milliseconds / 1000, tz=timezone.utc
    ).date().isoformat()


def _utc_month_start(now: int) -> int:
    current = datetime.fromtimestamp(now / 1000, tz=timezone.utc)
    start = datetime(current.year, current.month, 1, tzinfo=timezone.utc)
    return int(start.timestamp() * 1000)


def _usage_count(session: Session, start: int, end: int) -> int:
    return int(
        session.scalar(
            select(func.count())
            .select_from(AiUsageRecord)
            .where(
                AiUsageRecord.created_at >= start,
                AiUsageRecord.created_at <= end,
            )
        )
        or 0
    )


def _percentage(count: int, total: int) -> float:
    return round(count * 100 / total, 2) if total else 0.0


def _event(
    event: str,
    timestamp: int,
    provider: str,
    metric: str,
    value: int | float,
    threshold: int | float,
) -> dict[str, Any]:
    return {
        "event": event,
        "severity": (
            "critical" if event == "AI_USAGE_LIMIT_EXCEEDED" else "warning"
        ),
        "timestamp": timestamp,
        "provider": provider,
        "metric": metric,
        "value": value,
        "threshold": threshold,
    }


def _append_budget_event(
    events: list[dict[str, Any]],
    *,
    now: int,
    provider: str,
    metric: str,
    value: int,
    limit: int,
    warning_percent: int,
) -> None:
    warning_threshold = math.ceil(limit * warning_percent / 100)
    if value >= limit:
        events.append(
            _event(
                "AI_USAGE_LIMIT_EXCEEDED",
                now,
                provider,
                metric,
                value,
                limit,
            )
        )
    elif value >= warning_threshold:
        events.append(
            _event(
                "AI_USAGE_LIMIT_WARNING",
                now,
                provider,
                metric,
                value,
                warning_threshold,
            )
        )


def _provider_ready(settings: Settings) -> bool:
    if settings.ai_provider == "disabled":
        return True
    if settings.ai_provider == "fake":
        return settings.environment in {"development", "test"}
    if settings.ai_provider == "openai":
        return bool(settings.openai_api_key and settings.ai_model)
    if settings.ai_provider == "deepseek":
        return bool(settings.deepseek_api_key and settings.ai_model)
    return False


def _statuses_compatible(generation: str, usage: str) -> bool:
    expected = {
        "processing": {"processing", "expired"},
        "completed": {"completed"},
        "failed": {"failed"},
        "outcome_unknown": {"processing", "expired"},
    }
    return usage in expected.get(generation, set())


def _status_counts(
    rows: Any, *, attribute: str = "status"
) -> dict[str, int]:
    counts: dict[str, int] = defaultdict(int)
    for row in rows:
        counts[getattr(row, attribute)] += 1
    return dict(sorted(counts.items()))
