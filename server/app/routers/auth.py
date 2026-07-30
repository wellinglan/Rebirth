from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.database import get_session
from app.models import AuthSession, CloudUser
from app.schemas import (
    AuthSessionResponse,
    AuthUserResponse,
    DevLoginRequest,
    LogoutRequest,
    LogoutResponse,
    NotImplementedResponse,
    PasswordAttachRequest,
    PasswordAttachResponse,
    PasswordLoginRequest,
    PasswordRegisterRequest,
    RefreshTokenRequest,
    TokenResponse,
    WeChatMobileRequest,
)
from app.security import (
    AuthContext,
    optional_logout_auth_context,
    require_auth_context,
)
from app.services.auth_session_service import (
    AuthProtocolError,
    ClientMetadata,
    IssuedTokenPair,
    attach_password_identity,
    client_ip_prefix,
    dev_login as create_dev_session,
    login_password_user,
    register_password_user,
    revoke_by_refresh_token,
    revoke_session,
    rotate_refresh_token,
)
from app.services.wechat_auth_service import wechat_not_implemented


router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenResponse)
def register(
    body: PasswordRegisterRequest,
    request: Request,
    session: Session = Depends(get_session),
) -> TokenResponse:
    try:
        pair = register_password_user(
            session,
            username=body.username,
            password=body.password,
            display_name=body.display_name,
            metadata=_metadata(body, request),
            settings=request.app.state.settings,
        )
        return _token_response(pair)
    except AuthProtocolError as error:
        raise _http_error(error) from error


@router.post("/login", response_model=TokenResponse)
def login(
    body: PasswordLoginRequest,
    request: Request,
    session: Session = Depends(get_session),
) -> TokenResponse:
    try:
        pair = login_password_user(
            session,
            username=body.username,
            password=body.password,
            metadata=_metadata(body, request),
            client_ip_prefix=client_ip_prefix(
                request.client.host if request.client else None
            ),
            settings=request.app.state.settings,
        )
        return _token_response(pair)
    except AuthProtocolError as error:
        raise _http_error(error) from error


@router.post("/dev-login", response_model=TokenResponse)
def dev_login(
    body: DevLoginRequest,
    request: Request,
    session: Session = Depends(get_session),
) -> TokenResponse:
    settings = request.app.state.settings
    if settings.environment not in {"development", "test"}:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    try:
        pair = create_dev_session(
            session,
            dev_user_key=body.dev_user_key,
            metadata=_metadata(body, request),
            settings=settings,
        )
        return _token_response(pair)
    except AuthProtocolError as error:
        raise _http_error(error) from error


@router.post("/refresh", response_model=TokenResponse)
def refresh(
    body: RefreshTokenRequest,
    request: Request,
    session: Session = Depends(get_session),
) -> TokenResponse:
    try:
        pair = rotate_refresh_token(
            session,
            raw_token=body.refresh_token,
            metadata=_metadata(body, request),
            settings=request.app.state.settings,
        )
        return _token_response(pair)
    except AuthProtocolError as error:
        raise _http_error(error) from error


@router.post("/logout", response_model=LogoutResponse)
def logout(
    body: LogoutRequest,
    request: Request,
    context: AuthContext | None = Depends(optional_logout_auth_context),
    session: Session = Depends(get_session),
) -> LogoutResponse:
    if context is not None and context.session_id is not None:
        auth_session = session.get(AuthSession, context.session_id)
        if auth_session is not None:
            revoke_session(session, auth_session)
    elif body.refresh_token:
        revoke_by_refresh_token(
            session,
            body.refresh_token,
            settings=request.app.state.settings,
        )
    return LogoutResponse()


@router.get("/session", response_model=AuthSessionResponse)
def current_session(
    context: AuthContext = Depends(require_auth_context),
    session: Session = Depends(get_session),
) -> AuthSessionResponse:
    if context.session_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "code": "access_token_invalid",
                "message": "A session-backed access token is required.",
            },
        )
    auth_session = session.get_one(AuthSession, context.session_id)
    user = session.get_one(CloudUser, context.user_id)
    return AuthSessionResponse(
        session_id=auth_session.id,
        provider=context.provider,
        access_expires_at=context.access_expires_at,
        session_absolute_expires_at=auth_session.absolute_expires_at,
        user=AuthUserResponse(id=user.id, display_name=user.display_name),
    )


@router.post(
    "/identities/password/attach",
    response_model=PasswordAttachResponse,
)
def attach_password(
    body: PasswordAttachRequest,
    request: Request,
    context: AuthContext = Depends(require_auth_context),
    session: Session = Depends(get_session),
) -> PasswordAttachResponse:
    try:
        attach_password_identity(
            session,
            user_id=context.user_id,
            current_identity_id=context.identity_id,
            dev_user_key=body.dev_user_key,
            username=body.username,
            password=body.password,
            display_name=body.display_name,
            settings=request.app.state.settings,
        )
        user = session.get_one(CloudUser, context.user_id)
        return PasswordAttachResponse(
            user=AuthUserResponse(id=user.id, display_name=user.display_name)
        )
    except AuthProtocolError as error:
        raise _http_error(error) from error


@router.post("/wechat/mobile", response_model=NotImplementedResponse)
def wechat_mobile(_: WeChatMobileRequest) -> NotImplementedResponse:
    return wechat_not_implemented()


@router.get("/wechat/desktop/start", response_model=NotImplementedResponse)
def wechat_desktop_start() -> NotImplementedResponse:
    return wechat_not_implemented()


@router.get("/wechat/callback", response_model=NotImplementedResponse)
def wechat_callback() -> NotImplementedResponse:
    return wechat_not_implemented()


def _metadata(body: object, request: Request) -> ClientMetadata:
    return ClientMetadata(
        installation_id=getattr(body, "client_installation_id", None),
        platform=getattr(body, "platform", None),
        app_version=getattr(body, "app_version", None),
        user_agent=request.headers.get("user-agent"),
    )


def _token_response(pair: IssuedTokenPair) -> TokenResponse:
    return TokenResponse(
        access_token=pair.access_token,
        refresh_token=pair.refresh_token,
        access_expires_at=pair.access_expires_at,
        refresh_expires_at=pair.refresh_expires_at,
        session_id=pair.session_id,
        session_absolute_expires_at=pair.session_absolute_expires_at,
        identity_provider=pair.identity_provider,
        user=AuthUserResponse(
            id=pair.user.id,
            display_name=pair.user.display_name,
        ),
    )


def _http_error(error: AuthProtocolError) -> HTTPException:
    return HTTPException(
        status_code=error.status_code,
        detail={"code": error.code, "message": error.message},
        headers={"WWW-Authenticate": "Bearer"}
        if error.status_code == 401
        else None,
    )
