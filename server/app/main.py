from __future__ import annotations

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from collections.abc import Callable

from app.ai.providers import build_provider
from app.ai.service import AiGenerationService
from app.config import load_settings
from app.database import Database
from app.identity import WECHAT_PROVIDER
from app.oauth.providers import OAuthProviderAdapter, OAuthProviderRegistry
from app.routers import ai, auth, devices, health, sync


def create_app(
    *,
    database_url: str | None = None,
    environment: str | None = None,
    jwt_secret: str | None = None,
    auth_refresh_token_hmac_key: str | None = None,
    auth_dev_identity_hmac_key: str | None = None,
    auth_rate_limit_hmac_key: str | None = None,
    auth_legacy_token_migration_enabled: bool | None = None,
    auth_legacy_token_migration_deadline: str | None = None,
    wechat_app_id: str | None = None,
    wechat_app_secret: str | None = None,
    wechat_provider_adapter: OAuthProviderAdapter | None = None,
    oauth_clock: Callable[[], int] | None = None,
    ai_provider: str | None = None,
    openai_api_key: str | None = None,
    ai_model: str | None = None,
    openai_client: object | None = None,
    ai_clock: Callable[[], int] | None = None,
) -> FastAPI:
    settings = load_settings(
        database_url=database_url,
        environment=environment,
        jwt_secret=jwt_secret,
        auth_refresh_token_hmac_key=auth_refresh_token_hmac_key,
        auth_dev_identity_hmac_key=auth_dev_identity_hmac_key,
        auth_rate_limit_hmac_key=auth_rate_limit_hmac_key,
        auth_legacy_token_migration_enabled=(
            auth_legacy_token_migration_enabled
        ),
        auth_legacy_token_migration_deadline=(
            auth_legacy_token_migration_deadline
        ),
        wechat_app_id=wechat_app_id,
        wechat_app_secret=wechat_app_secret,
        ai_provider=ai_provider,
        openai_api_key=openai_api_key,
        ai_model=ai_model,
    )
    database = Database(settings.database_url)
    database.create_schema()

    application = FastAPI(title="Rebirth API", version="0.1.0-dev")
    application.state.settings = settings
    application.state.database = database
    application.state.oauth_provider_registry = OAuthProviderRegistry(
        adapters=(
            [wechat_provider_adapter]
            if wechat_provider_adapter is not None
            else []
        ),
        configured_provider_ids=(
            {WECHAT_PROVIDER}
            if settings.wechat_provider_configured
            else set()
        ),
    )
    application.state.oauth_clock = oauth_clock
    provider = build_provider(settings, openai_client=openai_client)
    application.state.ai_generation_service = (
        AiGenerationService(settings=settings, provider=provider)
        if ai_clock is None
        else AiGenerationService(
            settings=settings,
            provider=provider,
            clock=ai_clock,
        )
    )

    @application.exception_handler(RequestValidationError)
    async def validation_error_handler(
        request: object, error: RequestValidationError
    ) -> JSONResponse:
        del request, error
        return JSONResponse(
            status_code=422,
            content={
                "detail": {
                    "code": "invalid_request",
                    "message": "The request body is invalid.",
                }
            },
        )

    application.include_router(health.router)
    application.include_router(auth.router)
    application.include_router(devices.router)
    application.include_router(sync.router)
    application.include_router(ai.router)
    return application


app = create_app()
