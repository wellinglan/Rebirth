from __future__ import annotations

import os
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
        ai_timeout_seconds=float(os.getenv("REBIRTH_AI_TIMEOUT_SECONDS", "90")),
        ai_max_output_tokens=int(
            os.getenv("REBIRTH_AI_MAX_OUTPUT_TOKENS", "1600")
        ),
        ai_fake_scenario=os.getenv("REBIRTH_AI_FAKE_SCENARIO", "success").lower(),
    )
