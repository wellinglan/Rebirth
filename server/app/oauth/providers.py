from __future__ import annotations

from collections.abc import Mapping
from typing import Protocol

from app.identity import VerifiedProviderIdentity, VerifiedWechatIdentity


class OAuthProviderError(Exception):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


class OAuthProviderAdapter(Protocol):
    @property
    def provider_id(self) -> str: ...

    def exchange(
        self,
        *,
        authorization_code: str,
        nonce: str,
    ) -> VerifiedProviderIdentity: ...


class WechatIdentityProvider(OAuthProviderAdapter, Protocol):
    """WeChat code exchange only; account binding stays in IdentityService."""


class OAuthProviderRegistry:
    def __init__(
        self,
        *,
        adapters: list[OAuthProviderAdapter] | None = None,
        configured_provider_ids: set[str] | None = None,
    ) -> None:
        self._adapters = {
            adapter.provider_id: adapter for adapter in (adapters or [])
        }
        self._configured_provider_ids = configured_provider_ids or set()

    def is_ready(self, provider: str) -> bool:
        return (
            provider in self._configured_provider_ids
            and provider in self._adapters
        )

    def require_ready(self, provider: str) -> OAuthProviderAdapter:
        if not self.is_ready(provider):
            raise OAuthProviderError(
                "oauth_provider_unavailable",
                "The login method is unavailable.",
            )
        return self._adapters[provider]


class FakeWechatProvider:
    """Deterministic test adapter; never registered by the production app."""

    provider_id = "wechat"

    def __init__(
        self,
        responses: Mapping[str, VerifiedWechatIdentity],
    ) -> None:
        self._responses = dict(responses)

    def exchange(
        self,
        *,
        authorization_code: str,
        nonce: str,
    ) -> VerifiedProviderIdentity:
        if not nonce:
            raise OAuthProviderError(
                "oauth_provider_rejected",
                "The provider could not verify this request.",
            )
        verified = self._responses.get(authorization_code)
        if verified is None:
            raise OAuthProviderError(
                "oauth_provider_rejected",
                "The provider could not verify this request.",
            )
        return verified.as_provider_identity()
