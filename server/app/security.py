from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Literal

import jwt
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import InvalidTokenError

from app.config import Settings


_bearer = HTTPBearer(auto_error=False)


def create_access_token(user_id: str, settings: Settings) -> str:
    return _create_token(
        user_id=user_id,
        token_type="access",
        lifetime=timedelta(minutes=settings.access_token_minutes),
        settings=settings,
    )


def create_refresh_token(user_id: str, settings: Settings) -> str:
    return _create_token(
        user_id=user_id,
        token_type="refresh",
        lifetime=timedelta(days=settings.refresh_token_days),
        settings=settings,
    )


def _create_token(
    *,
    user_id: str,
    token_type: Literal["access", "refresh"],
    lifetime: timedelta,
    settings: Settings,
) -> str:
    issued_at = datetime.now(timezone.utc)
    payload = {
        "sub": user_id,
        "type": token_type,
        "iat": issued_at,
        "exp": issued_at + lifetime,
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def require_user_id(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> str:
    if credentials is None:
        raise _unauthorized()
    try:
        payload = jwt.decode(
            credentials.credentials,
            request.app.state.settings.jwt_secret,
            algorithms=["HS256"],
        )
    except InvalidTokenError as error:
        raise _unauthorized() from error

    if payload.get("type") != "access" or not isinstance(payload.get("sub"), str):
        raise _unauthorized()
    return payload["sub"]


def _unauthorized() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Valid Rebirth access token required.",
        headers={"WWW-Authenticate": "Bearer"},
    )
