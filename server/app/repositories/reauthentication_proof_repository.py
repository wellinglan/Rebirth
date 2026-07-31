from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import ReauthenticationProof


class ReauthenticationProofRepository:
    def __init__(self, session: Session) -> None:
        self._session = session

    def add(self, proof: ReauthenticationProof) -> None:
        self._session.add(proof)

    def get_by_hash_for_update(
        self,
        proof_hash: str,
    ) -> ReauthenticationProof | None:
        return self._session.scalar(
            select(ReauthenticationProof)
            .where(ReauthenticationProof.proof_hash == proof_hash)
            .with_for_update()
        )
