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

from app.identity import IdentityBindingError
from app.models import CloudUser, OAuthTransaction
from app.oauth.providers import OAuthProviderError, OAuthProviderRegistry
from app.repositories.oauth_transaction_repository import (
    OAuthTransactionRepository,
)
from app.services.identity_service import IdentityService


class OAuthPurpose(StrEnum):
    BIND = "bind"


class OAuthTransactionStatus(StrEnum):
    CREATED = "created"
    PROVIDER_VERIFIED = "provider_verified"
    COMPLETED = "completed"
    EXPIRED = "expired"
    CONSUMED = "consumed"
    REJECTED = "rejected"


_ALLOWED_TRANSITIONS = {
    OAuthTransactionStatus.CREATED: {
        OAuthTransactionStatus.PROVIDER_VERIFIED,
        OAuthTransactionStatus.EXPIRED,
        OAuthTransactionStatus.REJECTED,
    },
    OAuthTransactionStatus.PROVIDER_VERIFIED: {
        OAuthTransactionStatus.COMPLETED,
        OAuthTransactionStatus.REJECTED,
    },
    OAuthTransactionStatus.COMPLETED: {
        OAuthTransactionStatus.CONSUMED,
    },
    OAuthTransactionStatus.EXPIRED: set(),
    OAuthTransactionStatus.CONSUMED: set(),
    OAuthTransactionStatus.REJECTED: set(),
}


@dataclass(frozen=True)
class OAuthTransactionStart:
    transaction_id: str
    provider: str
    purpose: str
    state: str
    nonce: str
    expires_at: int


@dataclass(frozen=True)
class OAuthTransactionCompletion:
    transaction_id: str
    provider: str
    status: str


class OAuthTransactionError(Exception):
    def __init__(self, code: str, message: str, status_code: int) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code


class OAuthTransactionStateMachine:
    @staticmethod
    def transition(
        transaction: OAuthTransaction,
        target: OAuthTransactionStatus,
    ) -> None:
        current = OAuthTransactionStatus(transaction.status)
        if target not in _ALLOWED_TRANSITIONS[current]:
            raise OAuthTransactionError(
                "oauth_transaction_state_invalid",
                "The OAuth transaction cannot continue.",
                409,
            )
        transaction.status = target.value


class OAuthTransactionService:
    def __init__(
        self,
        session: Session,
        *,
        providers: OAuthProviderRegistry,
        transaction_minutes: int,
        clock: Callable[[], int] | None = None,
    ) -> None:
        self._session = session
        self._repository = OAuthTransactionRepository(session)
        self._providers = providers
        self._transaction_milliseconds = transaction_minutes * 60 * 1000
        self._clock = clock or (lambda: time.time_ns() // 1_000_000)

    def start(
        self,
        *,
        provider: str,
        purpose: OAuthPurpose,
        cloud_user_id: str,
    ) -> OAuthTransactionStart:
        self._require_user(cloud_user_id)
        self._require_provider(provider)
        now = self._clock()
        for _ in range(3):
            state = secrets.token_urlsafe(32)
            nonce = secrets.token_urlsafe(32)
            transaction = OAuthTransaction(
                transaction_id=str(uuid.uuid4()),
                provider=provider,
                purpose=purpose.value,
                cloud_user_id=cloud_user_id,
                state_hash=_hash_secret(state),
                nonce_hash=_hash_secret(nonce),
                status=OAuthTransactionStatus.CREATED.value,
                created_at=now,
                expires_at=now + self._transaction_milliseconds,
                consumed_at=None,
            )
            try:
                self._repository.add(transaction)
                self._session.commit()
                return OAuthTransactionStart(
                    transaction_id=transaction.transaction_id,
                    provider=provider,
                    purpose=purpose.value,
                    state=state,
                    nonce=nonce,
                    expires_at=transaction.expires_at,
                )
            except IntegrityError:
                self._session.rollback()
        raise OAuthTransactionError(
            "oauth_transaction_unavailable",
            "The OAuth transaction could not be created.",
            503,
        )

    def exchange(
        self,
        *,
        transaction_id: str,
        provider: str,
        purpose: OAuthPurpose,
        cloud_user_id: str,
        state: str,
        nonce: str,
        authorization_code: str,
        reauthentication_verified: bool,
    ) -> OAuthTransactionCompletion:
        if not reauthentication_verified:
            raise OAuthTransactionError(
                "reauthentication_required",
                "Please confirm the current login before binding.",
                403,
            )
        adapter = self._require_provider(provider)
        transaction = self._repository.get_for_update(transaction_id)
        if (
            transaction is None
            or transaction.cloud_user_id != cloud_user_id
            or transaction.provider != provider
            or transaction.purpose != purpose.value
        ):
            raise _transaction_unavailable()
        if transaction.status != OAuthTransactionStatus.CREATED.value:
            raise _transaction_unavailable()
        now = self._clock()
        if transaction.expires_at <= now:
            OAuthTransactionStateMachine.transition(
                transaction,
                OAuthTransactionStatus.EXPIRED,
            )
            self._session.commit()
            raise OAuthTransactionError(
                "oauth_transaction_expired",
                "The OAuth transaction has expired.",
                410,
            )
        if not secrets.compare_digest(
            transaction.state_hash,
            _hash_secret(state),
        ) or not secrets.compare_digest(
            transaction.nonce_hash,
            _hash_secret(nonce),
        ):
            raise _transaction_unavailable()

        try:
            verified_identity = adapter.exchange(
                authorization_code=authorization_code,
                nonce=nonce,
            )
            if verified_identity.provider != provider:
                raise OAuthProviderError(
                    "oauth_provider_rejected",
                    "The provider could not verify this request.",
                )
            OAuthTransactionStateMachine.transition(
                transaction,
                OAuthTransactionStatus.PROVIDER_VERIFIED,
            )
            self._session.flush()
            IdentityService(self._session).bind_verified_provider_identity(
                user_id=cloud_user_id,
                verified_identity=verified_identity,
                reauthentication_verified=True,
                now=now,
                commit=False,
            )
            OAuthTransactionStateMachine.transition(
                transaction,
                OAuthTransactionStatus.COMPLETED,
            )
            OAuthTransactionStateMachine.transition(
                transaction,
                OAuthTransactionStatus.CONSUMED,
            )
            transaction.consumed_at = now
            self._session.commit()
        except OAuthProviderError as error:
            OAuthTransactionStateMachine.transition(
                transaction,
                OAuthTransactionStatus.REJECTED,
            )
            self._session.commit()
            raise OAuthTransactionError(
                error.code,
                error.message,
                409,
            ) from error
        except IdentityBindingError as error:
            self._session.rollback()
            self._reject_after_rollback(transaction_id, cloud_user_id, now)
            raise OAuthTransactionError(
                error.code,
                error.message,
                error.status_code,
            ) from error
        except IntegrityError as error:
            self._session.rollback()
            self._reject_after_rollback(transaction_id, cloud_user_id, now)
            raise OAuthTransactionError(
                "identity_binding_unavailable",
                "The login method cannot be bound.",
                409,
            ) from error

        return OAuthTransactionCompletion(
            transaction_id=transaction_id,
            provider=provider,
            status="completed",
        )

    def _require_user(self, user_id: str) -> None:
        user = self._session.get(CloudUser, user_id)
        if user is None or user.deleted_at is not None:
            raise OAuthTransactionError(
                "authentication_required",
                "Authentication is required.",
                401,
            )

    def _require_provider(self, provider: str):
        try:
            return self._providers.require_ready(provider)
        except OAuthProviderError as error:
            raise OAuthTransactionError(
                error.code,
                error.message,
                503,
            ) from error

    def _reject_after_rollback(
        self,
        transaction_id: str,
        cloud_user_id: str,
        now: int,
    ) -> None:
        transaction = self._repository.get_for_update(transaction_id)
        if (
            transaction is not None
            and transaction.cloud_user_id == cloud_user_id
            and transaction.status
            in {
                OAuthTransactionStatus.CREATED.value,
                OAuthTransactionStatus.PROVIDER_VERIFIED.value,
            }
        ):
            transaction.status = OAuthTransactionStatus.REJECTED.value
            transaction.consumed_at = now
            self._session.commit()


def _hash_secret(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _transaction_unavailable() -> OAuthTransactionError:
    return OAuthTransactionError(
        "oauth_transaction_unavailable",
        "The OAuth transaction cannot continue.",
        409,
    )
