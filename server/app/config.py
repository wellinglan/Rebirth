from __future__ import annotations

import os
import math
import secrets
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path


_DEVELOPMENT_SECRETS = {
    "jwt": secrets.token_urlsafe(48),
    "refresh": secrets.token_urlsafe(48),
    "dev_identity": secrets.token_urlsafe(48),
    "rate_limit": secrets.token_urlsafe(48),
}


@dataclass(frozen=True)
class Settings:
    environment: str
    database_url: str
    jwt_secret: str = field(repr=False)
    access_token_minutes: int
    refresh_token_days: int
    auth_jwt_issuer: str
    auth_jwt_audience: str
    auth_refresh_token_hmac_key: str = field(repr=False)
    auth_dev_identity_hmac_key: str = field(repr=False)
    auth_rate_limit_hmac_key: str = field(repr=False)
    auth_session_absolute_days: int
    auth_legacy_token_migration_enabled: bool
    auth_legacy_token_migration_deadline: int | None
    auth_login_max_failures: int
    auth_login_window_minutes: int
    auth_login_block_minutes: int
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
    auth_refresh_token_hmac_key: str | None = None,
    auth_dev_identity_hmac_key: str | None = None,
    auth_rate_limit_hmac_key: str | None = None,
    auth_legacy_token_migration_enabled: bool | None = None,
    auth_legacy_token_migration_deadline: str | None = None,
    ai_provider: str | None = None,
    openai_api_key: str | None = None,
    ai_model: str | None = None,
) -> Settings:
    resolved_environment = (
        environment or os.getenv("REBIRTH_ENV", "development")
    ).lower()
    configured_secret = _secret(
        explicit=jwt_secret,
        env_name="REBIRTH_JWT_SECRET",
        environment=resolved_environment,
        development_key="jwt",
    )
    refresh_hmac_key = _secret(
        explicit=auth_refresh_token_hmac_key,
        env_name="AUTH_REFRESH_TOKEN_HMAC_KEY",
        environment=resolved_environment,
        development_key="refresh",
    )
    dev_identity_hmac_key = _secret(
        explicit=auth_dev_identity_hmac_key,
        env_name="AUTH_DEV_IDENTITY_HMAC_KEY",
        environment=resolved_environment,
        development_key="dev_identity",
    )
    rate_limit_hmac_key = _secret(
        explicit=auth_rate_limit_hmac_key,
        env_name="AUTH_RATE_LIMIT_HMAC_KEY",
        environment=resolved_environment,
        development_key="rate_limit",
    )
    legacy_enabled = (
        auth_legacy_token_migration_enabled
        if auth_legacy_token_migration_enabled is not None
        else _boolean("AUTH_LEGACY_TOKEN_MIGRATION_ENABLED", "false")
    )
    deadline_text = (
        auth_legacy_token_migration_deadline
        or os.getenv("AUTH_LEGACY_TOKEN_MIGRATION_DEADLINE")
    )
    legacy_deadline = _utc_deadline_milliseconds(deadline_text)
    if legacy_enabled and legacy_deadline is None:
        raise RuntimeError(
            "AUTH_LEGACY_TOKEN_MIGRATION_DEADLINE is required when legacy "
            "token migration is enabled."
        )

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
        access_token_minutes=_positive_int(
            "AUTH_ACCESS_TOKEN_MINUTES",
            os.getenv("REBIRTH_ACCESS_TOKEN_MINUTES", "15"),
        ),
        refresh_token_days=_positive_int(
            "AUTH_REFRESH_TOKEN_DAYS",
            os.getenv("REBIRTH_REFRESH_TOKEN_DAYS", "30"),
        ),
        auth_jwt_issuer=os.getenv("AUTH_JWT_ISSUER", "rebirth-api"),
        auth_jwt_audience=os.getenv("AUTH_JWT_AUDIENCE", "rebirth-client"),
        auth_refresh_token_hmac_key=refresh_hmac_key,
        auth_dev_identity_hmac_key=dev_identity_hmac_key,
        auth_rate_limit_hmac_key=rate_limit_hmac_key,
        auth_session_absolute_days=_positive_int(
            "AUTH_SESSION_ABSOLUTE_DAYS",
            "90",
        ),
        auth_legacy_token_migration_enabled=legacy_enabled,
        auth_legacy_token_migration_deadline=legacy_deadline,
        auth_login_max_failures=_positive_int("AUTH_LOGIN_MAX_FAILURES", "5"),
        auth_login_window_minutes=_positive_int(
            "AUTH_LOGIN_WINDOW_MINUTES",
            "15",
        ),
        auth_login_block_minutes=_positive_int(
            "AUTH_LOGIN_BLOCK_MINUTES",
            "15",
        ),
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


def _secret(
    *,
    explicit: str | None,
    env_name: str,
    environment: str,
    development_key: str,
) -> str:
    value = explicit or os.getenv(env_name)
    if value:
        if environment != "development" and len(value.encode("utf-8")) < 32:
            raise RuntimeError(f"{env_name} must be at least 32 bytes.")
        return value
    if environment == "development":
        return _DEVELOPMENT_SECRETS[development_key]
    raise RuntimeError(f"{env_name} is required outside development.")


def _boolean(name: str, default: str) -> bool:
    value = os.getenv(name, default).strip().lower()
    if value in {"1", "true", "yes", "on"}:
        return True
    if value in {"0", "false", "no", "off"}:
        return False
    raise RuntimeError(f"{name} must be true or false.")


def _utc_deadline_milliseconds(value: str | None) -> int | None:
    if value is None or not value.strip():
        return None
    try:
        parsed = datetime.fromisoformat(value.strip().replace("Z", "+00:00"))
    except ValueError:
        raise RuntimeError(
            "AUTH_LEGACY_TOKEN_MIGRATION_DEADLINE must be an ISO-8601 timestamp."
        ) from None
    if parsed.tzinfo is None:
        raise RuntimeError(
            "AUTH_LEGACY_TOKEN_MIGRATION_DEADLINE must include a timezone."
        )
    return int(parsed.astimezone(timezone.utc).timestamp() * 1000)
