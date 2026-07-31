from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum


PASSWORD_PROVIDER = "password_username"
DEV_PROVIDER = "dev"
WECHAT_PROVIDER = "wechat"


class IdentityCapability(StrEnum):
    LOGIN = "login"
    BIND = "bind"


@dataclass(frozen=True)
class IdentityProviderMetadata:
    provider_id: str
    display_name: str
    capabilities: frozenset[IdentityCapability]
    enabled: bool


IDENTITY_PROVIDERS = {
    PASSWORD_PROVIDER: IdentityProviderMetadata(
        provider_id=PASSWORD_PROVIDER,
        display_name="Username and password",
        capabilities=frozenset({IdentityCapability.LOGIN}),
        enabled=True,
    ),
    DEV_PROVIDER: IdentityProviderMetadata(
        provider_id=DEV_PROVIDER,
        display_name="Developer account",
        capabilities=frozenset({IdentityCapability.LOGIN}),
        enabled=True,
    ),
    WECHAT_PROVIDER: IdentityProviderMetadata(
        provider_id=WECHAT_PROVIDER,
        display_name="WeChat",
        capabilities=frozenset(
            {IdentityCapability.LOGIN, IdentityCapability.BIND}
        ),
        enabled=False,
    ),
}

_PUBLIC_PROVIDER_NAMES = {
    PASSWORD_PROVIDER: "password",
    DEV_PROVIDER: "developer",
    WECHAT_PROVIDER: "wechat",
}


def public_provider_name(provider: str) -> str:
    return _PUBLIC_PROVIDER_NAMES.get(provider, provider)


def provider_metadata(provider: str) -> IdentityProviderMetadata:
    try:
        return IDENTITY_PROVIDERS[provider]
    except KeyError as error:
        raise IdentityBindingError(
            "identity_provider_unsupported",
            "The login method is unavailable.",
            400,
        ) from error


@dataclass(frozen=True)
class IdentitySummary:
    provider: str
    created_at: int
    last_used_at: int | None


@dataclass(frozen=True)
class VerifiedWechatIdentity:
    app_id: str
    open_id: str
    union_id: str | None = None

    @property
    def normalized_union_id(self) -> str | None:
        return _validated_subject_part(self.union_id)

    @property
    def provider_subject(self) -> str:
        union_id = self.normalized_union_id
        if union_id is not None:
            return f"unionid:{union_id}"
        app_id = _validated_subject_part(self.app_id)
        open_id = _validated_subject_part(self.open_id)
        if app_id is None or open_id is None:
            raise IdentityBindingError(
                "identity_binding_unavailable",
                "The login method cannot be bound.",
                409,
            )
        return f"openid:{app_id}:{open_id}"


@dataclass(frozen=True)
class IdentityBindingAvailability:
    provider: str
    available: bool
    requires_reauthentication: bool


class IdentityBindingError(Exception):
    def __init__(self, code: str, message: str, status_code: int) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code


def _validated_subject_part(value: str | None) -> str | None:
    if value is None:
        return None
    normalized = value.strip()
    if (
        not normalized
        or len(normalized) > 200
        or any(ord(character) < 32 for character in normalized)
    ):
        raise IdentityBindingError(
            "identity_binding_unavailable",
            "The login method cannot be bound.",
            409,
        )
    return normalized
