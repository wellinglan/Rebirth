from __future__ import annotations

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.ai.providers import build_provider
from app.ai.service import AiGenerationService
from app.config import load_settings
from app.database import Database
from app.routers import ai, auth, devices, health, sync


def create_app(
    *,
    database_url: str | None = None,
    environment: str | None = None,
    jwt_secret: str | None = None,
    ai_provider: str | None = None,
    openai_api_key: str | None = None,
    ai_model: str | None = None,
    openai_client: object | None = None,
) -> FastAPI:
    settings = load_settings(
        database_url=database_url,
        environment=environment,
        jwt_secret=jwt_secret,
        ai_provider=ai_provider,
        openai_api_key=openai_api_key,
        ai_model=ai_model,
    )
    database = Database(settings.database_url)
    database.create_schema()

    application = FastAPI(title="Rebirth API", version="0.1.0-dev")
    application.state.settings = settings
    application.state.database = database
    application.state.ai_generation_service = AiGenerationService(
        settings=settings,
        provider=build_provider(settings, openai_client=openai_client),
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
