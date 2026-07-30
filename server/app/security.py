from __future__ import annotations

import time
import uuid
from dataclasses import dataclass
from typing import Any

import jwt
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import ExpiredSignatureError, InvalidTokenError
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import Settings
from app.database import get_session
from app.models import AuthIdentity, AuthSession, CloudUser


_bearer = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class AuthContext:
    user_id: str
    session_id: str | None
    identity_id: str
    provider: str
    access_expires_at: int
    legacy_access: bool = False


def create_access_token(
    *,
    user_id: str,
    session_id: str,
    identity_id: str,
    settings: Settings,
    now_milliseconds: int | None = None,
) -> tuple[str, int]:
    issued_at_ms = now_milliseconds or time.time_ns() // 1_000_000
    issued_at = issued_at_ms // 1000
    expires_at = issued_at + settings.access_token_minutes * 60
    payload = {
        "sub": user_id,
        "sid": session_id,
        "aid": identity_id,
        "type": "access",
        "jti": str(uuid.uuid4()),
        "iat": issued_at,
        "exp": expires_at,
        "iss": settings.auth_jwt_issuer,
        "aud": settings.auth_jwt_audience,
    }
    return (
        jwt.encode(payload, settings.jwt_secret, algorithm="HS256"),
        expires_at * 1000,
    )


def require_auth_context(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    session: Session = Depends(get_session),
) -> AuthContext:
    if credentials is None:
        raise _unauthorized("authentication_required")
    return _decode_auth_context(
        credentials.credentials,
        request.app.state.settings,
        session,
    )


def optional_logout_auth_context(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    session: Session = Depends(get_session),
) -> AuthContext | None:
    if credentials is None:
        return None
    try:
        return _decode_auth_context(
            credentials.credentials,
            request.app.state.settings,
            session,
        )
    except HTTPException:
        return None


def require_user_id(context: AuthContext = Depends(require_auth_context)) -> str:
    return context.user_id


def _decode_auth_context(
    token: str,
    settings: Settings,
    session: Session,
) -> AuthContext:
    try:
        payload: dict[str, Any] = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=["HS256"],
            audience=settings.auth_jwt_audience,
            issuer=settings.auth_jwt_issuer,
            options={
                "require": [
                    "sub",
                    "sid",
                    "aid",
                    "type",
                    "jti",
                    "iat",
                    "exp",
                    "iss",
                    "aud",
                ]
            },
        )
    except ExpiredSignatureError as error:
        raise _unauthorized("access_token_expired") from error
    except InvalidTokenError:
        return _decode_legacy_access(token, settings, session)

    if payload.get("type") != "access":
        raise _unauthorized("access_token_invalid")
    user_id = payload.get("sub")
    session_id = payload.get("sid")
    identity_id = payload.get("aid")
    expires_at = payload.get("exp")
    if not all(
        isinstance(value, str) for value in (user_id, session_id, identity_id)
    ) or not isinstance(expires_at, int):
        raise _unauthorized("access_token_invalid")
    auth_session = session.get(AuthSession, session_id)
    now = time.time_ns() // 1_000_000
    if auth_session is None:
        raise _unauthorized("access_token_invalid")
    if auth_session.revoked_at is not None:
        raise _unauthorized("session_revoked")
    if auth_session.absolute_expires_at <= now:
        raise _unauthorized("session_expired")
    if (
        auth_session.user_id != user_id
        or auth_session.identity_id != identity_id
    ):
        raise _unauthorized("access_token_invalid")
    identity = session.get(AuthIdentity, identity_id)
    if identity is None or identity.user_id != user_id:
        raise _unauthorized("access_token_invalid")
    return AuthContext(
        user_id=user_id,
        session_id=session_id,
        identity_id=identity_id,
        provider=identity.provider,
        access_expires_at=expires_at * 1000,
    )


def _decode_legacy_access(
    token: str,
    settings: Settings,
    session: Session,
) -> AuthContext:
    now = time.time_ns() // 1_000_000
    if (
        not settings.auth_legacy_token_migration_enabled
        or settings.auth_legacy_token_migration_deadline is None
        or now >= settings.auth_legacy_token_migration_deadline
    ):
        raise _unauthorized("access_token_invalid")
    try:
        payload: dict[str, Any] = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=["HS256"],
            options={"require": ["sub", "type", "iat", "exp"]},
        )
    except ExpiredSignatureError as error:
        raise _unauthorized("access_token_expired") from error
    except InvalidTokenError as error:
        raise _unauthorized("access_token_invalid") from error
    user_id = payload.get("sub")
    expires_at = payload.get("exp")
    if (
        payload.get("type") != "access"
        or not isinstance(user_id, str)
        or not isinstance(expires_at, int)
    ):
        raise _unauthorized("access_token_invalid")
    user = session.get(CloudUser, user_id)
    identity = session.scalar(
        select(AuthIdentity)
        .where(AuthIdentity.user_id == user_id)
        .order_by(AuthIdentity.created_at, AuthIdentity.id)
    )
    if user is None or user.deleted_at is not None or identity is None:
        raise _unauthorized("access_token_invalid")
    return AuthContext(
        user_id=user_id,
        session_id=None,
        identity_id=identity.id,
        provider=identity.provider,
        access_expires_at=expires_at * 1000,
        legacy_access=True,
    )


def _unauthorized(code: str) -> HTTPException:
    messages = {
        "authentication_required": "Valid Rebirth access token required.",
        "access_token_expired": "The access token has expired.",
        "session_revoked": "The session was revoked.",
        "session_expired": "The session has expired.",
    }
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail={
            "code": code,
            "message": messages.get(code, "The access token is invalid."),
        },
        headers={"WWW-Authenticate": "Bearer"},
    )
