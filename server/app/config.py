from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


_DEVELOPMENT_JWT_SECRET = "rebirth-development-only-not-a-production-secret"


@dataclass(frozen=True)
class Settings:
    environment: str
    database_url: str
    jwt_secret: str
    access_token_minutes: int
    refresh_token_days: int

    @property
    def is_development(self) -> bool:
        return self.environment == "development"


def load_settings(
    *,
    database_url: str | None = None,
    environment: str | None = None,
    jwt_secret: str | None = None,
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
    return Settings(
        environment=resolved_environment,
        database_url=resolved_database_url,
        jwt_secret=configured_secret,
        access_token_minutes=int(
            os.getenv("REBIRTH_ACCESS_TOKEN_MINUTES", "30")
        ),
        refresh_token_days=int(os.getenv("REBIRTH_REFRESH_TOKEN_DAYS", "30")),
    )
