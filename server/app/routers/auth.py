from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.database import get_session
from app.schemas import (
    AuthUserResponse,
    DevLoginRequest,
    NotImplementedResponse,
    TokenResponse,
    WeChatMobileRequest,
)
from app.security import create_access_token, create_refresh_token
from app.services.auth_service import find_or_create_dev_user
from app.services.wechat_auth_service import wechat_not_implemented


router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/dev-login", response_model=TokenResponse)
def dev_login(
    body: DevLoginRequest,
    request: Request,
    session: Session = Depends(get_session),
) -> TokenResponse:
    settings = request.app.state.settings
    if not settings.is_development:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

    user = find_or_create_dev_user(session, body.dev_user_key)
    return TokenResponse(
        access_token=create_access_token(user.id, settings),
        refresh_token=create_refresh_token(user.id, settings),
        user=AuthUserResponse(id=user.id, display_name=user.display_name),
    )


@router.post("/wechat/mobile", response_model=NotImplementedResponse)
def wechat_mobile(_: WeChatMobileRequest) -> NotImplementedResponse:
    return wechat_not_implemented()


@router.get("/wechat/desktop/start", response_model=NotImplementedResponse)
def wechat_desktop_start() -> NotImplementedResponse:
    return wechat_not_implemented()


@router.get("/wechat/callback", response_model=NotImplementedResponse)
def wechat_callback() -> NotImplementedResponse:
    return wechat_not_implemented()
