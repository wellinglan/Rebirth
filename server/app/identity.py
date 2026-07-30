from __future__ import annotations

from dataclasses import dataclass


PASSWORD_PROVIDER = "password_username"
DEV_PROVIDER = "dev"

_PUBLIC_PROVIDER_NAMES = {
    PASSWORD_PROVIDER: "password",
    DEV_PROVIDER: "developer",
}


def public_provider_name(provider: str) -> str:
    return _PUBLIC_PROVIDER_NAMES.get(provider, provider)


@dataclass(frozen=True)
class IdentitySummary:
    provider: str
    created_at: int
    last_used_at: int | None
