from __future__ import annotations

import uuid

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.identity import (
    IdentityBindingAvailability,
    IdentityBindingError,
    IdentityCapability,
    IdentitySummary,
    VerifiedProviderIdentity,
    VerifiedWechatIdentity,
    provider_metadata,
    public_provider_name,
)
from app.models import AuthIdentity, CloudUser
from app.repositories.identity_repository import IdentityRepository


class IdentityService:
    def __init__(self, session: Session) -> None:
        self._session = session
        self._repository = IdentityRepository(session)

    def list_for_user(self, user_id: str) -> list[IdentitySummary]:
        return [
            IdentitySummary(
                provider=public_provider_name(identity.provider),
                created_at=identity.created_at,
                last_used_at=identity.last_used_at,
            )
            for identity in self._repository.list_for_user(user_id)
        ]

    def record_used(self, identity: AuthIdentity, now: int) -> None:
        identity.last_used_at = now
        identity.updated_at = max(identity.updated_at, now)

    def binding_availability(
        self,
        *,
        user_id: str,
        provider: str,
    ) -> IdentityBindingAvailability:
        user = self._session.get(CloudUser, user_id)
        if user is None or user.deleted_at is not None:
            raise IdentityBindingError(
                "authentication_required",
                "Authentication is required.",
                401,
            )
        metadata = provider_metadata(provider)
        return IdentityBindingAvailability(
            provider=public_provider_name(provider),
            available=(
                metadata.enabled
                and IdentityCapability.BIND in metadata.capabilities
            ),
            requires_reauthentication=True,
        )

    def bind_verified_wechat_identity(
        self,
        *,
        user_id: str,
        verified_identity: VerifiedWechatIdentity,
        reauthentication_verified: bool,
        now: int,
        commit: bool = True,
    ) -> AuthIdentity:
        return self.bind_verified_provider_identity(
            user_id=user_id,
            verified_identity=verified_identity.as_provider_identity(),
            reauthentication_verified=reauthentication_verified,
            now=now,
            commit=commit,
        )

    def bind_verified_provider_identity(
        self,
        *,
        user_id: str,
        verified_identity: VerifiedProviderIdentity,
        reauthentication_verified: bool,
        now: int,
        commit: bool = True,
    ) -> AuthIdentity:
        if not reauthentication_verified:
            raise IdentityBindingError(
                "reauthentication_required",
                "Please confirm the current login before binding.",
                403,
            )
        user = self._session.get(CloudUser, user_id)
        if user is None or user.deleted_at is not None:
            raise IdentityBindingError(
                "authentication_required",
                "Authentication is required.",
                401,
            )
        metadata = provider_metadata(verified_identity.provider)
        if IdentityCapability.BIND not in metadata.capabilities:
            raise IdentityBindingError(
                "identity_binding_unavailable",
                "The login method cannot be bound.",
                409,
            )
        subject = verified_identity.provider_subject
        if (
            self._repository.find_by_provider_subject(
                verified_identity.provider,
                subject,
                for_update=True,
            )
            is not None
        ):
            raise IdentityBindingError(
                "identity_binding_unavailable",
                "The login method cannot be bound.",
                409,
            )
        identity = AuthIdentity(
            id=str(uuid.uuid4()),
            user_id=user_id,
            provider=verified_identity.provider,
            provider_subject=subject,
            provider_union_id=verified_identity.provider_union_id,
            created_at=now,
            updated_at=now,
            last_used_at=None,
        )
        try:
            self._repository.add(identity)
            self._session.flush()
            if commit:
                self._session.commit()
            return identity
        except IntegrityError as error:
            if commit:
                self._session.rollback()
            raise IdentityBindingError(
                "identity_binding_unavailable",
                "The login method cannot be bound.",
                409,
            ) from error
