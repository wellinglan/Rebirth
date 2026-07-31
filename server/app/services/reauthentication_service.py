from __future__ import annotations

import hashlib
import secrets
import time
import uuid
from collections.abc import Callable
from dataclasses import dataclass
from enum import StrEnum

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.config import Settings
from app.models import AuthSession, ReauthenticationProof
from app.repositories.reauthentication_proof_repository import (
    ReauthenticationProofRepository,
)
from app.services.auth_session_service import (
    AuthProtocolError,
    reauthenticate_developer_user,
    reauthenticate_password_user,
)


class ReauthenticationPurpose(StrEnum):
    WECHAT_BIND = "wechat_bind"


class ReauthenticationProofStatus(StrEnum):
    CREATED = "created"
    CONSUMED = "consumed"
    EXPIRED = "expired"
    REJECTED = "rejected"


@dataclass(frozen=True)
class IssuedReauthenticationProof:
    proof: str
    purpose: str
    expires_at: int
    method: str


class ReauthenticationError(Exception):
    def __init__(self, code: str, message: str, status_code: int) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code


class ReauthenticationService:
    def __init__(
        self,
        session: Session,
        *,
        settings: Settings,
        clock: Callable[[], int] | None = None,
    ) -> None:
        self._session = session
        self._settings = settings
        self._repository = ReauthenticationProofRepository(session)
        self._clock = clock or (lambda: time.time_ns() // 1_000_000)
        self._lifetime_ms = settings.reauthentication_proof_minutes * 60_000

    def issue_password(
        self,
        *,
        cloud_user_id: str,
        session_id: str,
        password: str,
        purpose: ReauthenticationPurpose,
    ) -> IssuedReauthenticationProof:
        self._require_active_session(cloud_user_id, session_id)
        try:
            reauthenticate_password_user(
                self._session,
                user_id=cloud_user_id,
                session_id=session_id,
                password=password,
                settings=self._settings,
            )
        except AuthProtocolError as error:
            raise ReauthenticationError(
                error.code,
                error.message,
                error.status_code,
            ) from error
        return self._issue(
            cloud_user_id=cloud_user_id,
            session_id=session_id,
            purpose=purpose,
            method="password",
        )

    def issue_developer(
        self,
        *,
        cloud_user_id: str,
        session_id: str,
        identity_id: str,
        dev_user_key: str,
        purpose: ReauthenticationPurpose,
    ) -> IssuedReauthenticationProof:
        self._require_active_session(cloud_user_id, session_id)
        try:
            reauthenticate_developer_user(
                self._session,
                user_id=cloud_user_id,
                identity_id=identity_id,
                dev_user_key=dev_user_key,
                settings=self._settings,
            )
        except AuthProtocolError as error:
            raise ReauthenticationError(
                error.code,
                error.message,
                error.status_code,
            ) from error
        return self._issue(
            cloud_user_id=cloud_user_id,
            session_id=session_id,
            purpose=purpose,
            method="developer",
        )

    def consume(
        self,
        *,
        raw_proof: str,
        cloud_user_id: str,
        session_id: str,
        purpose: ReauthenticationPurpose,
        commit: bool = True,
    ) -> None:
        proof = self._repository.get_by_hash_for_update(_hash_proof(raw_proof))
        if (
            proof is None
            or proof.cloud_user_id != cloud_user_id
            or proof.session_id != session_id
            or proof.purpose != purpose.value
        ):
            raise _invalid_proof()
        if proof.status == ReauthenticationProofStatus.CONSUMED.value:
            raise ReauthenticationError(
                "reauthentication_proof_consumed",
                "The reauthentication proof has already been used.",
                409,
            )
        if proof.status != ReauthenticationProofStatus.CREATED.value:
            raise _invalid_proof()
        now = self._clock()
        if proof.expires_at <= now:
            proof.status = ReauthenticationProofStatus.EXPIRED.value
            proof.consumed_at = now
            self._session.commit()
            raise ReauthenticationError(
                "reauthentication_proof_expired",
                "The reauthentication proof has expired.",
                410,
            )
        self._require_active_session(cloud_user_id, session_id)
        proof.status = ReauthenticationProofStatus.CONSUMED.value
        proof.consumed_at = now
        if commit:
            self._session.commit()
        else:
            self._session.flush()

    def _issue(
        self,
        *,
        cloud_user_id: str,
        session_id: str,
        purpose: ReauthenticationPurpose,
        method: str,
    ) -> IssuedReauthenticationProof:
        now = self._clock()
        raw_proof = secrets.token_urlsafe(32)
        record = ReauthenticationProof(
            id=str(uuid.uuid4()),
            cloud_user_id=cloud_user_id,
            session_id=session_id,
            purpose=purpose.value,
            proof_hash=_hash_proof(raw_proof),
            created_at=now,
            expires_at=now + self._lifetime_ms,
            consumed_at=None,
            status=ReauthenticationProofStatus.CREATED.value,
        )
        self._repository.add(record)
        try:
            self._session.commit()
        except IntegrityError as error:
            self._session.rollback()
            raise ReauthenticationError(
                "reauthentication_unavailable",
                "Reauthentication could not be completed.",
                503,
            ) from error
        return IssuedReauthenticationProof(
            proof=raw_proof,
            purpose=purpose.value,
            expires_at=record.expires_at,
            method=method,
        )

    def _require_active_session(
        self,
        cloud_user_id: str,
        session_id: str,
    ) -> AuthSession:
        auth_session = self._session.get(AuthSession, session_id)
        now = self._clock()
        if (
            auth_session is None
            or auth_session.user_id != cloud_user_id
            or auth_session.revoked_at is not None
            or auth_session.absolute_expires_at <= now
        ):
            raise ReauthenticationError(
                "reauthentication_required",
                "An active authenticated session is required.",
                401,
            )
        return auth_session


def _hash_proof(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _invalid_proof() -> ReauthenticationError:
    return ReauthenticationError(
        "reauthentication_proof_invalid",
        "The reauthentication proof is invalid.",
        403,
    )
