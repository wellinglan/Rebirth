from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import AuthIdentity


class IdentityRepository:
    def __init__(self, session: Session) -> None:
        self._session = session

    def list_for_user(self, user_id: str) -> list[AuthIdentity]:
        return list(
            self._session.scalars(
                select(AuthIdentity)
                .where(AuthIdentity.user_id == user_id)
                .order_by(AuthIdentity.created_at, AuthIdentity.id)
            )
        )

    def find_by_provider_subject(
        self,
        provider: str,
        provider_subject: str,
        *,
        for_update: bool = False,
    ) -> AuthIdentity | None:
        statement = select(AuthIdentity).where(
            AuthIdentity.provider == provider,
            AuthIdentity.provider_subject == provider_subject,
        )
        if for_update:
            statement = statement.with_for_update()
        return self._session.scalar(statement)

    def find_for_user_provider(
        self,
        user_id: str,
        provider: str,
    ) -> AuthIdentity | None:
        return self._session.scalar(
            select(AuthIdentity).where(
                AuthIdentity.user_id == user_id,
                AuthIdentity.provider == provider,
            )
        )

    def first_for_user(self, user_id: str) -> AuthIdentity | None:
        return self._session.scalar(
            select(AuthIdentity)
            .where(AuthIdentity.user_id == user_id)
            .order_by(AuthIdentity.created_at, AuthIdentity.id)
        )
