from __future__ import annotations

from sqlalchemy.orm import Session

from app.identity import IdentitySummary, public_provider_name
from app.models import AuthIdentity
from app.repositories.identity_repository import IdentityRepository


class IdentityService:
    def __init__(self, session: Session) -> None:
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
