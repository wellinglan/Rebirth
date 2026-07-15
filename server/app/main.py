from __future__ import annotations

from fastapi import FastAPI

from app.config import load_settings
from app.database import Database
from app.routers import auth, devices, health, sync


def create_app(
    *,
    database_url: str | None = None,
    environment: str | None = None,
    jwt_secret: str | None = None,
) -> FastAPI:
    settings = load_settings(
        database_url=database_url,
        environment=environment,
        jwt_secret=jwt_secret,
    )
    database = Database(settings.database_url)
    database.create_schema()

    application = FastAPI(title="Rebirth API", version="0.1.0-dev")
    application.state.settings = settings
    application.state.database = database
    application.include_router(health.router)
    application.include_router(auth.router)
    application.include_router(devices.router)
    application.include_router(sync.router)
    return application


app = create_app()
