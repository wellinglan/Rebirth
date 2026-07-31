from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import OAuthTransaction


class OAuthTransactionRepository:
    def __init__(self, session: Session) -> None:
        self._session = session

    def add(self, transaction: OAuthTransaction) -> None:
        self._session.add(transaction)

    def get_for_update(self, transaction_id: str) -> OAuthTransaction | None:
        return self._session.scalar(
            select(OAuthTransaction)
            .where(OAuthTransaction.transaction_id == transaction_id)
            .with_for_update()
        )
