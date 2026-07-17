from __future__ import annotations

import hashlib
import json
import logging
from typing import Any


logger = logging.getLogger("rebirth.ai")
logger.setLevel(logging.INFO)

AI_LOG_EVENTS = frozenset(
    {
        "ai_request_claimed",
        "ai_request_replayed",
        "ai_request_processing",
        "ai_request_conflict",
        "ai_request_outcome_unknown",
        "ai_provider_started",
        "ai_provider_completed",
        "ai_provider_failed",
        "ai_result_purged",
        "ai_tombstone_deleted",
        "ai_status_recovered",
    }
)

_ALLOWED_FIELDS = frozenset(
    {
        "event",
        "request_id",
        "pseudonymous_user_id",
        "provider",
        "model",
        "status",
        "error_code",
        "latency_ms",
        "input_hash_prefix",
        "result_purge_count",
        "tombstone_delete_count",
        "environment",
    }
)


def pseudonymous_user_id(user_id: str, environment: str) -> str:
    namespaced = f"rebirth.ai.user.v1:{environment}:{user_id}"
    return hashlib.sha256(namespaced.encode("utf-8")).hexdigest()


def log_ai_event(
    event: str,
    *,
    environment: str,
    user_id: str | None = None,
    input_hash: str | None = None,
    **fields: Any,
) -> None:
    _ensure_runtime_handler()
    if event not in AI_LOG_EVENTS:
        raise ValueError("Unsupported AI observability event.")
    record: dict[str, Any] = {"event": event, "environment": environment}
    if user_id is not None:
        record["pseudonymous_user_id"] = pseudonymous_user_id(
            user_id, environment
        )
    if input_hash is not None:
        record["input_hash_prefix"] = input_hash[:8]
    for key, value in fields.items():
        if key not in _ALLOWED_FIELDS:
            raise ValueError("Unsupported AI observability field.")
        if value is not None:
            record[key] = value
    logger.info(json.dumps(record, sort_keys=True, separators=(",", ":")))


def _ensure_runtime_handler() -> None:
    if logger.handlers or logging.getLogger().handlers:
        return
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(handler)
    logger.propagate = False
