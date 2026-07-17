from __future__ import annotations

import os
import math
from dataclasses import dataclass, field
from pathlib import Path


_DEVELOPMENT_JWT_SECRET = "rebirth-development-only-not-a-production-secret"


@dataclass(frozen=True)
class Settings:
    environment: str
    database_url: str
    jwt_secret: str
    access_token_minutes: int
    refresh_token_days: int
    ai_provider: str = "disabled"
    openai_api_key: str | None = field(default=None, repr=False)
    ai_model: str | None = None
    ai_timeout_seconds: float = 90.0
    ai_max_output_tokens: int = 1600
    ai_fake_scenario: str = "success"
    ai_result_retention_hours: int = 24
    ai_dedupe_retention_days: int = 30
    ai_processing_lease_minutes: int = 5

    @property
    def is_development(self) -> bool:
        return self.environment == "development"


def load_settings(
    *,
    database_url: str | None = None,
    environment: str | None = None,
    jwt_secret: str | None = None,
    ai_provider: str | None = None,
    openai_api_key: str | None = None,
    ai_model: str | None = None,
) -> Settings:
    resolved_environment = (
        environment or os.getenv("REBIRTH_ENV", "development")
    ).lower()
    configured_secret = jwt_secret or os.getenv("REBIRTH_JWT_SECRET")
    if not configured_secret:
        if resolved_environment != "development":
            raise RuntimeError(
                "REBIRTH_JWT_SECRET is required outside development."
            )
        configured_secret = _DEVELOPMENT_JWT_SECRET

    database_path = Path(__file__).resolve().parents[1] / "rebirth_dev.sqlite"
    resolved_database_url = (
        database_url
        or os.getenv("REBIRTH_DATABASE_URL")
        or f"sqlite:///{database_path.as_posix()}"
    )
    resolved_ai_provider = (
        ai_provider or os.getenv("REBIRTH_AI_PROVIDER", "disabled")
    ).lower()
    if resolved_ai_provider not in {"disabled", "fake", "openai"}:
        raise RuntimeError("REBIRTH_AI_PROVIDER must be disabled, fake, or openai.")
    resolved_api_key = openai_api_key or os.getenv("OPENAI_API_KEY")
    resolved_ai_model = ai_model or os.getenv("REBIRTH_AI_MODEL")
    if resolved_ai_provider == "fake" and resolved_environment not in {
        "development",
        "test",
    }:
        raise RuntimeError("The fake AI provider is development/test only.")
    if resolved_ai_provider == "openai":
        if not resolved_api_key:
            raise RuntimeError("OPENAI_API_KEY is required for the OpenAI provider.")
        if not resolved_ai_model:
            raise RuntimeError("REBIRTH_AI_MODEL is required for the OpenAI provider.")

    ai_timeout_seconds = _positive_float("REBIRTH_AI_TIMEOUT_SECONDS", "90")
    ai_max_output_tokens = _positive_int("REBIRTH_AI_MAX_OUTPUT_TOKENS", "1600")
    result_retention_hours = _positive_int(
        "REBIRTH_AI_RESULT_RETENTION_HOURS", "24"
    )
    dedupe_retention_days = _positive_int(
        "REBIRTH_AI_DEDUPE_RETENTION_DAYS", "30"
    )
    processing_lease_minutes = _positive_int(
        "REBIRTH_AI_PROCESSING_LEASE_MINUTES", "5"
    )
    result_retention_seconds = result_retention_hours * 60 * 60
    dedupe_retention_seconds = dedupe_retention_days * 24 * 60 * 60
    processing_lease_seconds = processing_lease_minutes * 60
    if processing_lease_seconds < ai_timeout_seconds + 30:
        raise RuntimeError(
            "REBIRTH_AI_PROCESSING_LEASE_MINUTES must allow at least 30 seconds "
            "beyond REBIRTH_AI_TIMEOUT_SECONDS."
        )
    if dedupe_retention_seconds < result_retention_seconds:
        raise RuntimeError(
            "REBIRTH_AI_DEDUPE_RETENTION_DAYS must not be shorter than "
            "REBIRTH_AI_RESULT_RETENTION_HOURS."
        )
    if dedupe_retention_seconds <= processing_lease_seconds:
        raise RuntimeError(
            "REBIRTH_AI_DEDUPE_RETENTION_DAYS must be longer than "
            "REBIRTH_AI_PROCESSING_LEASE_MINUTES."
        )

    return Settings(
        environment=resolved_environment,
        database_url=resolved_database_url,
        jwt_secret=configured_secret,
        access_token_minutes=int(
            os.getenv("REBIRTH_ACCESS_TOKEN_MINUTES", "30")
        ),
        refresh_token_days=int(os.getenv("REBIRTH_REFRESH_TOKEN_DAYS", "30")),
        ai_provider=resolved_ai_provider,
        openai_api_key=resolved_api_key,
        ai_model=resolved_ai_model,
        ai_timeout_seconds=ai_timeout_seconds,
        ai_max_output_tokens=ai_max_output_tokens,
        ai_fake_scenario=os.getenv("REBIRTH_AI_FAKE_SCENARIO", "success").lower(),
        ai_result_retention_hours=result_retention_hours,
        ai_dedupe_retention_days=dedupe_retention_days,
        ai_processing_lease_minutes=processing_lease_minutes,
    )


def _positive_int(name: str, default: str) -> int:
    try:
        value = int(os.getenv(name, default))
    except (TypeError, ValueError):
        raise RuntimeError(f"{name} must be a positive integer.") from None
    if value <= 0:
        raise RuntimeError(f"{name} must be a positive integer.")
    return value


def _positive_float(name: str, default: str) -> float:
    try:
        value = float(os.getenv(name, default))
    except (TypeError, ValueError):
        raise RuntimeError(f"{name} must be a finite positive number.") from None
    if not math.isfinite(value) or value <= 0:
        raise RuntimeError(f"{name} must be a finite positive number.")
    return value
