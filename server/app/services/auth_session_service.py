from __future__ import annotations

import hashlib
import hmac
import secrets
import time
import unicodedata
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

import jwt
from argon2 import PasswordHasher, Type
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError
from jwt import InvalidTokenError
from sqlalchemy import delete, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.config import Settings
from app.models import (
    AuthCredential,
    AuthIdentity,
    AuthLoginThrottle,
    AuthRefreshToken,
    AuthSession,
    CloudUser,
    LegacyRefreshMigration,
)
from app.security import create_access_token


PASSWORD_PROVIDER = "password_username"
DEV_PROVIDER = "dev"
PASSWORD_ALGORITHM = "argon2id"
PASSWORD_PARAMETERS_VERSION = 1


@dataclass(frozen=True)
class ClientMetadata:
    installation_id: str | None = None
    platform: str | None = None
    app_version: str | None = None
    user_agent: str | None = None


@dataclass(frozen=True)
class IssuedTokenPair:
    access_token: str
    refresh_token: str
    access_expires_at: int
    refresh_expires_at: int
    session_id: str
    session_absolute_expires_at: int
    identity_provider: str
    user: CloudUser


class AuthProtocolError(Exception):
    def __init__(self, code: str, message: str, status_code: int = 401) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code


def normalize_username(username: str) -> str:
    if username != username.strip():
        raise AuthProtocolError(
            "invalid_request",
            "The login identifier is invalid.",
            422,
        )
    normalized = username.lower()
    if not 4 <= len(normalized) <= 64:
        raise AuthProtocolError(
            "invalid_request",
            "The login identifier is invalid.",
            422,
        )
    if not normalized[0].isalnum() or not normalized[0].isascii():
        raise AuthProtocolError(
            "invalid_request",
            "The login identifier is invalid.",
            422,
        )
    allowed = set("abcdefghijklmnopqrstuvwxyz0123456789._-")
    if any(character not in allowed for character in normalized):
        raise AuthProtocolError(
            "invalid_request",
            "The login identifier is invalid.",
            422,
        )
    return normalized


def validate_password(password: str) -> None:
    if not 12 <= len(password) <= 128:
        raise AuthProtocolError(
            "password_policy_violation",
            "The password does not meet the security requirements.",
            422,
        )
    if any(
        character == "\x00"
        or unicodedata.category(character).startswith("C")
        for character in password
    ):
        raise AuthProtocolError(
            "password_policy_violation",
            "The password does not meet the security requirements.",
            422,
        )


def register_password_user(
    session: Session,
    *,
    username: str,
    password: str,
    display_name: str | None,
    metadata: ClientMetadata,
    settings: Settings,
) -> IssuedTokenPair:
    normalized = normalize_username(username)
    validate_password(password)
    now = _utc_milliseconds()
    user = CloudUser(
        id=str(uuid.uuid4()),
        display_name=_display_name(display_name),
        created_at=now,
        updated_at=now,
        deleted_at=None,
    )
    identity = AuthIdentity(
        id=str(uuid.uuid4()),
        user_id=user.id,
        provider=PASSWORD_PROVIDER,
        provider_subject=normalized,
        provider_union_id=None,
        created_at=now,
        updated_at=now,
    )
    credential = _new_password_credential(
        identity_id=identity.id,
        password=password,
        settings=settings,
        now=now,
    )
    try:
        session.add(user)
        session.flush()
        session.add(identity)
        session.flush()
        session.add(credential)
        session.flush()
        pair = _issue_new_session(
            session,
            user=user,
            identity=identity,
            metadata=metadata,
            settings=settings,
            now=now,
        )
        session.commit()
        return pair
    except IntegrityError as error:
        session.rollback()
        raise AuthProtocolError(
            "login_identifier_unavailable",
            "The login identifier is unavailable.",
            409,
        ) from error


def login_password_user(
    session: Session,
    *,
    username: str,
    password: str,
    metadata: ClientMetadata,
    client_ip_prefix: str,
    settings: Settings,
) -> IssuedTokenPair:
    normalized = normalize_username(username)
    bucket = _rate_limit_bucket(
        normalized,
        client_ip_prefix,
        "password_login",
        settings,
    )
    now = _utc_milliseconds()
    _check_rate_limit(session, bucket, now)
    identity = session.scalar(
        select(AuthIdentity).where(
            AuthIdentity.provider == PASSWORD_PROVIDER,
            AuthIdentity.provider_subject == normalized,
        )
    )
    credential = None
    if identity is not None:
        credential = session.scalar(
            select(AuthCredential).where(
                AuthCredential.identity_id == identity.id,
                AuthCredential.credential_type == "password",
                AuthCredential.disabled_at.is_(None),
            )
        )
    valid = _verify_password(
        password,
        credential.password_hash if credential is not None else None,
        settings,
    )
    if not valid or identity is None or credential is None:
        _record_login_failure(session, bucket, now, settings)
        raise AuthProtocolError(
            "invalid_credentials",
            "The login identifier or password is incorrect.",
        )
    user = session.get(CloudUser, identity.user_id)
    if user is None or user.deleted_at is not None:
        _record_login_failure(session, bucket, now, settings)
        raise AuthProtocolError(
            "invalid_credentials",
            "The login identifier or password is incorrect.",
        )
    if _password_hasher(settings).check_needs_rehash(credential.password_hash):
        credential.password_hash = _password_hasher(settings).hash(password)
        credential.updated_at = now
        credential.password_changed_at = now
    session.execute(
        delete(AuthLoginThrottle).where(AuthLoginThrottle.bucket_key == bucket)
    )
    pair = _issue_new_session(
        session,
        user=user,
        identity=identity,
        metadata=metadata,
        settings=settings,
        now=now,
    )
    session.commit()
    return pair


def dev_login(
    session: Session,
    *,
    dev_user_key: str,
    metadata: ClientMetadata,
    settings: Settings,
) -> IssuedTokenPair:
    normalized_key = dev_user_key.strip()
    if not normalized_key:
        raise AuthProtocolError("invalid_request", "The request body is invalid.", 422)
    subject = _hmac_hex(settings.auth_dev_identity_hmac_key, normalized_key)
    identity = session.scalar(
        select(AuthIdentity).where(
            AuthIdentity.provider == DEV_PROVIDER,
            AuthIdentity.provider_subject == subject,
        )
    )
    now = _utc_milliseconds()
    if identity is None:
        legacy = session.scalar(
            select(AuthIdentity)
            .where(
                AuthIdentity.provider == DEV_PROVIDER,
                AuthIdentity.provider_subject == normalized_key,
            )
            .with_for_update()
        )
        if legacy is not None:
            identity = legacy
            user = session.get_one(CloudUser, identity.user_id)
            if user.display_name == f"Dev {normalized_key}"[:128]:
                user.display_name = "Alpha User"
                user.updated_at = now
            identity.provider_subject = subject
            identity.updated_at = now
            session.flush()
        else:
            user = CloudUser(
                id=str(uuid.uuid4()),
                display_name="Alpha User",
                created_at=now,
                updated_at=now,
                deleted_at=None,
            )
            identity = AuthIdentity(
                id=str(uuid.uuid4()),
                user_id=user.id,
                provider=DEV_PROVIDER,
                provider_subject=subject,
                provider_union_id=None,
                created_at=now,
                updated_at=now,
            )
            session.add(user)
            try:
                session.flush()
                session.add(identity)
                session.flush()
            except IntegrityError:
                session.rollback()
                identity = session.scalar(
                    select(AuthIdentity).where(
                        AuthIdentity.provider == DEV_PROVIDER,
                        AuthIdentity.provider_subject == subject,
                    )
                )
                if identity is None:
                    raise
    user = session.get_one(CloudUser, identity.user_id)
    pair = _issue_new_session(
        session,
        user=user,
        identity=identity,
        metadata=metadata,
        settings=settings,
        now=now,
    )
    session.commit()
    return pair


def attach_password_identity(
    session: Session,
    *,
    user_id: str,
    current_identity_id: str,
    dev_user_key: str,
    username: str,
    password: str,
    display_name: str | None,
    settings: Settings,
) -> AuthIdentity:
    current_identity = session.get(AuthIdentity, current_identity_id)
    if (
        current_identity is None
        or current_identity.user_id != user_id
        or current_identity.provider != DEV_PROVIDER
    ):
        raise AuthProtocolError(
            "dev_reauthentication_failed",
            "Development account verification failed.",
            403,
        )
    expected = _hmac_hex(settings.auth_dev_identity_hmac_key, dev_user_key.strip())
    if not hmac.compare_digest(current_identity.provider_subject, expected):
        raise AuthProtocolError(
            "dev_reauthentication_failed",
            "Development account verification failed.",
            403,
        )
    existing = session.scalar(
        select(AuthIdentity).where(
            AuthIdentity.user_id == user_id,
            AuthIdentity.provider == PASSWORD_PROVIDER,
        )
    )
    if existing is not None:
        raise AuthProtocolError(
            "identity_already_attached",
            "A password identity is already attached.",
            409,
        )
    normalized = normalize_username(username)
    validate_password(password)
    now = _utc_milliseconds()
    identity = AuthIdentity(
        id=str(uuid.uuid4()),
        user_id=user_id,
        provider=PASSWORD_PROVIDER,
        provider_subject=normalized,
        provider_union_id=None,
        created_at=now,
        updated_at=now,
    )
    credential = _new_password_credential(
        identity_id=identity.id,
        password=password,
        settings=settings,
        now=now,
    )
    try:
        session.add(identity)
        session.flush()
        session.add(credential)
        user = session.get_one(CloudUser, user_id)
        safe_name = _display_name(display_name)
        if safe_name is not None:
            user.display_name = safe_name
            user.updated_at = now
        session.commit()
        return identity
    except IntegrityError as error:
        session.rollback()
        raise AuthProtocolError(
            "login_identifier_unavailable",
            "The login identifier is unavailable.",
            409,
        ) from error


def rotate_refresh_token(
    session: Session,
    *,
    raw_token: str,
    metadata: ClientMetadata,
    settings: Settings,
) -> IssuedTokenPair:
    parsed = _parse_opaque_refresh_token(raw_token)
    if parsed is None:
        return _migrate_legacy_refresh(
            session,
            raw_token=raw_token,
            metadata=metadata,
            settings=settings,
        )
    token_id, _ = parsed
    token = session.get(AuthRefreshToken, token_id)
    if token is None or not _refresh_hash_matches(token, raw_token, settings):
        raise AuthProtocolError(
            "refresh_token_invalid",
            "The refresh token is invalid.",
        )
    auth_session = session.get(AuthSession, token.session_id)
    now = _utc_milliseconds()
    if auth_session is None:
        raise AuthProtocolError(
            "refresh_token_invalid",
            "The refresh token is invalid.",
        )
    if token.used_at is not None or token.revoked_at is not None:
        _revoke_session_family(session, auth_session, now, "refresh_token_reused")
        session.commit()
        raise AuthProtocolError(
            "refresh_token_reused",
            "The refresh token can no longer be used.",
        )
    if token.expires_at <= now:
        raise AuthProtocolError(
            "refresh_token_expired",
            "The refresh token has expired.",
        )
    if auth_session.revoked_at is not None:
        raise AuthProtocolError("session_revoked", "The session was revoked.")
    if auth_session.absolute_expires_at <= now:
        _revoke_session_family(session, auth_session, now, "session_expired")
        session.commit()
        raise AuthProtocolError("session_expired", "The session has expired.")
    consumed = session.execute(
        update(AuthRefreshToken)
        .where(
            AuthRefreshToken.id == token.id,
            AuthRefreshToken.used_at.is_(None),
            AuthRefreshToken.revoked_at.is_(None),
        )
        .values(used_at=now)
    )
    if consumed.rowcount != 1:
        session.expire_all()
        current_session = session.get_one(AuthSession, auth_session.id)
        _revoke_session_family(
            session,
            current_session,
            now,
            "refresh_token_reused",
        )
        session.commit()
        raise AuthProtocolError(
            "refresh_token_reused",
            "The refresh token can no longer be used.",
        )
    identity = session.get_one(AuthIdentity, auth_session.identity_id)
    user = session.get_one(CloudUser, auth_session.user_id)
    next_token, raw_next, refresh_expires_at = _new_refresh_token(
        auth_session,
        settings=settings,
        now=now,
        parent_token_id=token.id,
    )
    session.add(next_token)
    session.flush()
    token.replaced_by_token_id = next_token.id
    auth_session.refresh_generation = next_token.generation
    auth_session.last_seen_at = now
    _apply_metadata(auth_session, metadata, settings)
    access_token, access_expires_at = create_access_token(
        user_id=user.id,
        session_id=auth_session.id,
        identity_id=identity.id,
        settings=settings,
        now_milliseconds=now,
    )
    session.commit()
    return IssuedTokenPair(
        access_token=access_token,
        refresh_token=raw_next,
        access_expires_at=access_expires_at,
        refresh_expires_at=refresh_expires_at,
        session_id=auth_session.id,
        session_absolute_expires_at=auth_session.absolute_expires_at,
        identity_provider=identity.provider,
        user=user,
    )


def revoke_session(
    session: Session,
    auth_session: AuthSession,
    *,
    reason: str = "logout",
) -> None:
    now = _utc_milliseconds()
    _revoke_session_family(session, auth_session, now, reason)
    session.commit()


def revoke_by_refresh_token(
    session: Session,
    raw_token: str,
    *,
    settings: Settings,
) -> None:
    parsed = _parse_opaque_refresh_token(raw_token)
    if parsed is None:
        return
    token = session.get(AuthRefreshToken, parsed[0])
    if token is None or not _refresh_hash_matches(token, raw_token, settings):
        return
    auth_session = session.get(AuthSession, token.session_id)
    if auth_session is not None:
        revoke_session(session, auth_session)


def _issue_new_session(
    session: Session,
    *,
    user: CloudUser,
    identity: AuthIdentity,
    metadata: ClientMetadata,
    settings: Settings,
    now: int,
    legacy_migrated_at: int | None = None,
) -> IssuedTokenPair:
    absolute_expires_at = now + settings.auth_session_absolute_days * 86_400_000
    auth_session = AuthSession(
        id=str(uuid.uuid4()),
        user_id=user.id,
        identity_id=identity.id,
        created_at=now,
        last_seen_at=now,
        absolute_expires_at=absolute_expires_at,
        revoked_at=None,
        revoke_reason=None,
        client_installation_id_hash=None,
        platform=None,
        app_version=None,
        user_agent_hash=None,
        refresh_generation=0,
        legacy_migrated_at=legacy_migrated_at,
    )
    _apply_metadata(auth_session, metadata, settings)
    refresh, raw_refresh, refresh_expires_at = _new_refresh_token(
        auth_session,
        settings=settings,
        now=now,
        parent_token_id=None,
    )
    session.add(auth_session)
    session.flush()
    session.add(refresh)
    session.flush()
    access_token, access_expires_at = create_access_token(
        user_id=user.id,
        session_id=auth_session.id,
        identity_id=identity.id,
        settings=settings,
        now_milliseconds=now,
    )
    return IssuedTokenPair(
        access_token=access_token,
        refresh_token=raw_refresh,
        access_expires_at=access_expires_at,
        refresh_expires_at=refresh_expires_at,
        session_id=auth_session.id,
        session_absolute_expires_at=absolute_expires_at,
        identity_provider=identity.provider,
        user=user,
    )


def _new_refresh_token(
    auth_session: AuthSession,
    *,
    settings: Settings,
    now: int,
    parent_token_id: str | None,
) -> tuple[AuthRefreshToken, str, int]:
    token_id = str(uuid.uuid4())
    raw_token = f"{token_id}.{secrets.token_urlsafe(32)}"
    expires_at = min(
        now + settings.refresh_token_days * 86_400_000,
        auth_session.absolute_expires_at,
    )
    generation = auth_session.refresh_generation + 1
    return (
        AuthRefreshToken(
            id=token_id,
            session_id=auth_session.id,
            token_hash=_hmac_hex(
                settings.auth_refresh_token_hmac_key,
                raw_token,
            ),
            parent_token_id=parent_token_id,
            issued_at=now,
            expires_at=expires_at,
            used_at=None,
            revoked_at=None,
            revoke_reason=None,
            replaced_by_token_id=None,
            generation=generation,
        ),
        raw_token,
        expires_at,
    )


def _migrate_legacy_refresh(
    session: Session,
    *,
    raw_token: str,
    metadata: ClientMetadata,
    settings: Settings,
) -> IssuedTokenPair:
    now = _utc_milliseconds()
    if (
        not settings.auth_legacy_token_migration_enabled
        or settings.auth_legacy_token_migration_deadline is None
        or now >= settings.auth_legacy_token_migration_deadline
    ):
        raise AuthProtocolError(
            "legacy_token_migration_closed",
            "The legacy session migration window is closed.",
        )
    try:
        claims: dict[str, Any] = jwt.decode(
            raw_token,
            settings.jwt_secret,
            algorithms=["HS256"],
            options={"require": ["sub", "type", "iat", "exp"]},
        )
    except InvalidTokenError as error:
        raise AuthProtocolError(
            "refresh_token_invalid",
            "The refresh token is invalid.",
        ) from error
    if claims.get("type") != "refresh" or not isinstance(claims.get("sub"), str):
        raise AuthProtocolError(
            "refresh_token_invalid",
            "The refresh token is invalid.",
        )
    legacy_hash = _hmac_hex(settings.auth_refresh_token_hmac_key, raw_token)
    if session.scalar(
        select(LegacyRefreshMigration.id).where(
            LegacyRefreshMigration.legacy_token_hash == legacy_hash
        )
    ):
        raise AuthProtocolError(
            "refresh_token_reused",
            "The refresh token can no longer be used.",
        )
    user = session.get(CloudUser, claims["sub"])
    if user is None or user.deleted_at is not None:
        raise AuthProtocolError(
            "refresh_token_invalid",
            "The refresh token is invalid.",
        )
    identity = session.scalar(
        select(AuthIdentity)
        .where(AuthIdentity.user_id == user.id)
        .order_by(AuthIdentity.created_at, AuthIdentity.id)
    )
    if identity is None:
        raise AuthProtocolError(
            "refresh_token_invalid",
            "The refresh token is invalid.",
        )
    pair = _issue_new_session(
        session,
        user=user,
        identity=identity,
        metadata=metadata,
        settings=settings,
        now=now,
        legacy_migrated_at=now,
    )
    session.add(
        LegacyRefreshMigration(
            id=str(uuid.uuid4()),
            legacy_token_hash=legacy_hash,
            session_id=pair.session_id,
            migrated_at=now,
        )
    )
    try:
        session.commit()
    except IntegrityError as error:
        session.rollback()
        raise AuthProtocolError(
            "refresh_token_reused",
            "The refresh token can no longer be used.",
        ) from error
    return pair


def _new_password_credential(
    *,
    identity_id: str,
    password: str,
    settings: Settings,
    now: int,
) -> AuthCredential:
    return AuthCredential(
        id=str(uuid.uuid4()),
        identity_id=identity_id,
        credential_type="password",
        password_hash=_password_hasher(settings).hash(password),
        password_algorithm=PASSWORD_ALGORITHM,
        password_parameters_version=PASSWORD_PARAMETERS_VERSION,
        created_at=now,
        updated_at=now,
        password_changed_at=now,
        disabled_at=None,
    )


def _password_hasher(settings: Settings) -> PasswordHasher:
    if settings.environment == "test":
        return PasswordHasher(
            time_cost=1,
            memory_cost=8192,
            parallelism=1,
            hash_len=32,
            salt_len=16,
            type=Type.ID,
        )
    return PasswordHasher(type=Type.ID)


def _verify_password(
    password: str,
    password_hash: str | None,
    settings: Settings,
) -> bool:
    hasher = _password_hasher(settings)
    candidate_hash = password_hash or hasher.hash(
        "Rebirth dummy verification password"
    )
    try:
        return hasher.verify(candidate_hash, password) and password_hash is not None
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        return False


def _check_rate_limit(session: Session, bucket: str, now: int) -> None:
    throttle = session.scalar(
        select(AuthLoginThrottle)
        .where(AuthLoginThrottle.bucket_key == bucket)
        .with_for_update()
    )
    if throttle is not None and throttle.blocked_until is not None:
        if throttle.blocked_until > now:
            session.rollback()
            raise AuthProtocolError(
                "authentication_rate_limited",
                "Too many authentication attempts. Try again later.",
                429,
            )


def _record_login_failure(
    session: Session,
    bucket: str,
    now: int,
    settings: Settings,
) -> None:
    window_ms = settings.auth_login_window_minutes * 60_000
    throttle = session.scalar(
        select(AuthLoginThrottle)
        .where(AuthLoginThrottle.bucket_key == bucket)
        .with_for_update()
    )
    if throttle is None:
        throttle = AuthLoginThrottle(
            bucket_key=bucket,
            failed_count=0,
            window_started_at=now,
            blocked_until=None,
            updated_at=now,
        )
        session.add(throttle)
    if now - throttle.window_started_at >= window_ms:
        throttle.failed_count = 0
        throttle.window_started_at = now
        throttle.blocked_until = None
    throttle.failed_count += 1
    throttle.updated_at = now
    if throttle.failed_count >= settings.auth_login_max_failures:
        throttle.blocked_until = (
            now + settings.auth_login_block_minutes * 60_000
        )
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        _record_login_failure(session, bucket, now, settings)


def _revoke_session_family(
    session: Session,
    auth_session: AuthSession,
    now: int,
    reason: str,
) -> None:
    if auth_session.revoked_at is None:
        auth_session.revoked_at = now
        auth_session.revoke_reason = reason
    session.execute(
        update(AuthRefreshToken)
        .where(
            AuthRefreshToken.session_id == auth_session.id,
            AuthRefreshToken.revoked_at.is_(None),
        )
        .values(revoked_at=now, revoke_reason=reason)
    )


def _apply_metadata(
    auth_session: AuthSession,
    metadata: ClientMetadata,
    settings: Settings,
) -> None:
    if metadata.installation_id:
        auth_session.client_installation_id_hash = _hmac_hex(
            settings.auth_rate_limit_hmac_key,
            metadata.installation_id,
        )
    if metadata.user_agent:
        auth_session.user_agent_hash = _hmac_hex(
            settings.auth_rate_limit_hmac_key,
            metadata.user_agent,
        )
    auth_session.platform = metadata.platform
    auth_session.app_version = metadata.app_version


def _rate_limit_bucket(
    username: str,
    ip_prefix: str,
    purpose: str,
    settings: Settings,
) -> str:
    return _hmac_hex(
        settings.auth_rate_limit_hmac_key,
        f"{purpose}\n{username}\n{ip_prefix}",
    )


def _refresh_hash_matches(
    token: AuthRefreshToken,
    raw_token: str,
    settings: Settings,
) -> bool:
    expected = _hmac_hex(settings.auth_refresh_token_hmac_key, raw_token)
    return hmac.compare_digest(token.token_hash, expected)


def _parse_opaque_refresh_token(raw_token: str) -> tuple[str, str] | None:
    if raw_token.count(".") != 1:
        return None
    token_id, secret = raw_token.split(".", 1)
    try:
        normalized_id = str(uuid.UUID(token_id))
    except ValueError:
        return None
    if not secret:
        return None
    return normalized_id, secret


def _hmac_hex(key: str, value: str) -> str:
    return hmac.new(
        key.encode("utf-8"),
        value.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def _display_name(value: str | None) -> str | None:
    if value is None:
        return None
    trimmed = value.strip()
    if not trimmed:
        return None
    return trimmed[:128]


def client_ip_prefix(host: str | None) -> str:
    if not host:
        return "unknown"
    if ":" in host:
        return ":".join(host.split(":")[:4])
    parts = host.split(".")
    return ".".join(parts[:3]) if len(parts) == 4 else "unknown"


def _utc_milliseconds() -> int:
    return time.time_ns() // 1_000_000
