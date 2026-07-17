from __future__ import annotations

import hashlib
import json
import math
from typing import Any

from app.ai.schemas import AiWeeklyPayload


def normalized_payload(payload: AiWeeklyPayload) -> dict[str, Any]:
    value = payload.model_dump(mode="json", exclude_none=False)
    value["data"] = {
        key: item for key, item in value["data"].items() if item is not None
    }
    value["scopes"] = sorted(value["scopes"])
    value["sources"] = sorted(
        value["sources"], key=lambda item: (item["table"], item["id"])
    )
    for key, date_key in (
        ("today_metrics", "record_date"),
        ("health_metrics", "record_date"),
        ("journal_reflections", "entry_date"),
    ):
        rows = value["data"].get(key)
        if rows is not None:
            value["data"][key] = sorted(rows, key=lambda item: item[date_key])
    return value


def canonical_json(value: Any) -> str:
    _reject_non_finite(value)
    return json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    )


def input_hash(payload: AiWeeklyPayload) -> str:
    encoded = canonical_json(normalized_payload(payload)).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _reject_non_finite(value: Any) -> None:
    if isinstance(value, float) and not math.isfinite(value):
        raise ValueError("non-finite JSON number")
    if isinstance(value, dict):
        for item in value.values():
            _reject_non_finite(item)
    elif isinstance(value, list):
        for item in value:
            _reject_non_finite(item)
