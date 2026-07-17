from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse

from app.ai.errors import AiGatewayError
from app.ai.schemas import (
    AiCapabilitiesResponse,
    AiWeeklyGenerateRequest,
    AiWeeklyGenerateResponse,
)
from app.security import require_user_id


router = APIRouter(prefix="/ai", tags=["ai"])


@router.get("/capabilities", response_model=AiCapabilitiesResponse)
def capabilities(
    request: Request,
    user_id: str = Depends(require_user_id),
) -> AiCapabilitiesResponse:
    del user_id
    return request.app.state.ai_generation_service.capabilities()


@router.post(
    "/reports/weekly/generate",
    response_model=AiWeeklyGenerateResponse,
    responses={422: {"description": "Controlled AI input error"}},
)
async def generate_weekly(
    body: AiWeeklyGenerateRequest,
    request: Request,
    user_id: str = Depends(require_user_id),
) -> AiWeeklyGenerateResponse | JSONResponse:
    try:
        return await request.app.state.ai_generation_service.generate_weekly(
            body, user_id=user_id
        )
    except AiGatewayError as error:
        return JSONResponse(
            status_code=error.status_code,
            content={"detail": {"code": error.code, "message": _message(error.code)}},
        )


def _message(code: str) -> str:
    messages = {
        "gateway_disabled": "AI generation is disabled on this server.",
        "input_hash_mismatch": "The AI input hash does not match the payload.",
        "unsupported_report_type": "The report type is not supported.",
        "unsupported_prompt_version": "The prompt version is not supported.",
        "unsupported_scope": "One or more scopes are not supported.",
        "provider_authentication_failed": "The AI provider could not authenticate.",
        "provider_rate_limited": "The AI provider rate limit was reached.",
        "provider_timeout": "The AI provider request timed out.",
        "provider_unavailable": "The AI provider is temporarily unavailable.",
        "provider_refused": "The AI provider refused this request.",
        "response_invalid": "The AI provider returned an invalid response.",
    }
    return messages.get(code, "The AI request could not be completed.")
