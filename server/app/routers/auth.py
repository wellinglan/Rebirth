from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.database import get_session
from app.identity import WECHAT_PROVIDER
from app.models import AuthSession, CloudUser
from app.schemas import (
    AuthIdentitiesResponse,
    AuthIdentitySummaryResponse,
    AuthSessionResponse,
    AuthUserResponse,
    DevLoginRequest,
    DeveloperReauthenticationRequest,
    LogoutRequest,
    LogoutResponse,
    NotImplementedResponse,
    PasswordAttachRequest,
    PasswordAttachResponse,
    PasswordLoginRequest,
    PasswordReauthenticationRequest,
    PasswordRegisterRequest,
    RefreshTokenRequest,
    ReauthenticationProofResponse,
    TokenResponse,
    WeChatBindingCallbackRequest,
    WeChatBindingCallbackResponse,
    WeChatBindingStartRequest,
    WeChatBindingStartResponse,
    WeChatBindingTransactionResponse,
    WeChatMobileRequest,
)
from app.security import (
    AuthContext,
    optional_logout_auth_context,
    require_auth_context,
)
from app.oauth.service import (
    OAuthPurpose,
    OAuthTransactionError,
    OAuthTransactionService,
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
from app.services.identity_service import IdentityService
from app.services.reauthentication_service import (
    ReauthenticationError,
    ReauthenticationPurpose,
    ReauthenticationService,
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


@router.get("/identities", response_model=AuthIdentitiesResponse)
def current_identities(
    context: AuthContext = Depends(require_auth_context),
    session: Session = Depends(get_session),
) -> AuthIdentitiesResponse:
    identities = IdentityService(session).list_for_user(context.user_id)
    return AuthIdentitiesResponse(
        identities=[
            AuthIdentitySummaryResponse(
                provider=identity.provider,
                created_at=identity.created_at,
                last_used_at=identity.last_used_at,
            )
            for identity in identities
        ]
    )


@router.post(
    "/reauthenticate/password",
    response_model=ReauthenticationProofResponse,
)
def reauthenticate_password(
    body: PasswordReauthenticationRequest,
    request: Request,
    context: AuthContext = Depends(require_auth_context),
    session: Session = Depends(get_session),
) -> ReauthenticationProofResponse:
    session_id = _require_session_id(context)
    try:
        result = _reauthentication_service(request, session).issue_password(
            cloud_user_id=context.user_id,
            session_id=session_id,
            password=body.password,
            purpose=ReauthenticationPurpose(body.purpose),
        )
    except ReauthenticationError as error:
        raise _reauthentication_http_error(error) from error
    return ReauthenticationProofResponse(
        purpose=result.purpose,
        method="password",
        proof=result.proof,
        expires_at=result.expires_at,
    )


@router.post(
    "/reauthenticate/developer",
    response_model=ReauthenticationProofResponse,
)
def reauthenticate_developer(
    body: DeveloperReauthenticationRequest,
    request: Request,
    context: AuthContext = Depends(require_auth_context),
    session: Session = Depends(get_session),
) -> ReauthenticationProofResponse:
    if request.app.state.settings.environment not in {"development", "test"}:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    session_id = _require_session_id(context)
    try:
        result = _reauthentication_service(request, session).issue_developer(
            cloud_user_id=context.user_id,
            session_id=session_id,
            identity_id=context.identity_id,
            dev_user_key=body.dev_user_key,
            purpose=ReauthenticationPurpose(body.purpose),
        )
    except ReauthenticationError as error:
        raise _reauthentication_http_error(error) from error
    return ReauthenticationProofResponse(
        purpose=result.purpose,
        method="developer",
        proof=result.proof,
        expires_at=result.expires_at,
    )


@router.post(
    "/identities/wechat/bind/start",
    response_model=(
        WeChatBindingStartResponse | WeChatBindingTransactionResponse
    ),
)
def start_wechat_binding(
    body: WeChatBindingStartRequest,
    request: Request,
    context: AuthContext = Depends(require_auth_context),
    session: Session = Depends(get_session),
) -> WeChatBindingStartResponse | WeChatBindingTransactionResponse:
    session_id = _require_session_id(context)
    try:
        _reauthentication_service(request, session).consume(
            raw_proof=body.reauthentication_proof,
            cloud_user_id=context.user_id,
            session_id=session_id,
            purpose=ReauthenticationPurpose.WECHAT_BIND,
            commit=False,
        )
        result = OAuthTransactionService(
            session,
            providers=request.app.state.oauth_provider_registry,
            transaction_minutes=(
                request.app.state.settings.wechat_oauth_transaction_minutes
            ),
            clock=request.app.state.oauth_clock,
        ).start(
            provider=WECHAT_PROVIDER,
            purpose=OAuthPurpose.WECHAT_BIND,
            cloud_user_id=context.user_id,
            session_id=session_id,
            commit=False,
        )
        session.commit()
    except ReauthenticationError as error:
        session.rollback()
        raise _reauthentication_http_error(error) from error
    except OAuthTransactionError as error:
        session.rollback()
        if error.code == "oauth_provider_unavailable":
            return WeChatBindingStartResponse()
        raise HTTPException(
            status_code=error.status_code,
            detail={"code": error.code, "message": error.message},
        ) from error
    return WeChatBindingTransactionResponse(
        transaction_id=result.transaction_id,
        state=result.state,
        nonce=result.nonce,
        expires_at=result.expires_at,
    )


@router.post(
    "/identities/wechat/bind/callback",
    response_model=WeChatBindingCallbackResponse,
)
def complete_wechat_binding(
    body: WeChatBindingCallbackRequest,
    request: Request,
    context: AuthContext = Depends(require_auth_context),
    session: Session = Depends(get_session),
) -> WeChatBindingCallbackResponse:
    session_id = _require_session_id(context)
    try:
        result = OAuthTransactionService(
            session,
            providers=request.app.state.oauth_provider_registry,
            transaction_minutes=(
                request.app.state.settings.wechat_oauth_transaction_minutes
            ),
            clock=request.app.state.oauth_clock,
        ).exchange(
            transaction_id=body.transaction_id,
            provider=WECHAT_PROVIDER,
            purpose=OAuthPurpose.WECHAT_BIND,
            cloud_user_id=context.user_id,
            session_id=session_id,
            state=body.state,
            nonce=body.nonce,
            authorization_code=body.authorization_code,
        )
    except OAuthTransactionError as error:
        raise HTTPException(
            status_code=error.status_code,
            detail={"code": error.code, "message": error.message},
        ) from error
    return WeChatBindingCallbackResponse(
        transaction_id=result.transaction_id,
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


def _reauthentication_service(
    request: Request,
    session: Session,
) -> ReauthenticationService:
    return ReauthenticationService(
        session,
        settings=request.app.state.settings,
        clock=request.app.state.reauthentication_clock,
    )


def _reauthentication_http_error(
    error: ReauthenticationError,
) -> HTTPException:
    return HTTPException(
        status_code=error.status_code,
        detail={"code": error.code, "message": error.message},
    )


def _require_session_id(context: AuthContext) -> str:
    if context.session_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "code": "reauthentication_required",
                "message": "A session-backed access token is required.",
            },
        )
    return context.session_id
