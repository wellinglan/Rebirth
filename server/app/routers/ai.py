from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.ai.errors import AiGatewayError
from app.ai.schemas import (
    AiCapabilitiesResponse,
    AiErrorResponse,
    AiRequestStatusResponse,
    AiWeeklyGenerateRequest,
    AiWeeklyGenerateResponse,
)
from app.database import get_session
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
    responses={
        202: {
            "model": AiRequestStatusResponse,
            "description": "The request is already processing.",
        },
        409: {
            "model": AiErrorResponse,
            "description": "Idempotency conflict or unknown provider outcome.",
        },
        410: {
            "model": AiErrorResponse,
            "description": "The temporary result has expired.",
        },
        422: {
            "model": AiErrorResponse,
            "description": "Invalid input or unsupported AI contract.",
        },
        429: {"model": AiErrorResponse, "description": "Provider rate limited."},
        502: {
            "model": AiErrorResponse,
            "description": "Provider, request, or response failure.",
        },
        503: {"model": AiErrorResponse, "description": "Provider unavailable."},
        504: {"model": AiErrorResponse, "description": "Provider timeout."},
    },
)
async def generate_weekly(
    body: AiWeeklyGenerateRequest,
    request: Request,
    user_id: str = Depends(require_user_id),
    session: Session = Depends(get_session),
) -> AiWeeklyGenerateResponse | AiRequestStatusResponse | JSONResponse:
    try:
        result = await request.app.state.ai_generation_service.generate_weekly(
            body, user_id=user_id, session=session
        )
        if isinstance(result, AiRequestStatusResponse):
            return JSONResponse(
                status_code=202,
                content=result.model_dump(mode="json"),
            )
        return result
    except AiGatewayError as error:
        return JSONResponse(
            status_code=error.status_code,
            content={"detail": {"code": error.code, "message": _message(error.code)}},
        )


@router.get(
    "/requests/{request_id}",
    response_model=AiRequestStatusResponse,
    responses={
        401: {"model": AiErrorResponse, "description": "Authentication required."},
        404: {"model": AiErrorResponse, "description": "Request not found."},
    },
)
def request_status(
    request_id: str,
    request: Request,
    user_id: str = Depends(require_user_id),
    session: Session = Depends(get_session),
) -> AiRequestStatusResponse | JSONResponse:
    try:
        from uuid import UUID

        normalized_id = str(UUID(request_id))
    except ValueError:
        return _error_response("not_found", status_code=404)
    try:
        result = request.app.state.ai_generation_service.get_request_status(
            normalized_id,
            user_id=user_id,
            session=session,
        )
    except AiGatewayError as error:
        return _error_response(error.code, status_code=error.status_code)
    if result is None:
        return _error_response("not_found", status_code=404)
    return result


def _error_response(code: str, *, status_code: int) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={"detail": {"code": code, "message": _message(code)}},
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
        "idempotency_conflict": "The request ID is already bound to different input.",
        "request_in_progress": "The request is still processing.",
        "outcome_unknown": "The provider outcome cannot be determined safely.",
        "result_expired": "The temporary server result is no longer available.",
        "not_found": "The AI request was not found.",
    }
    return messages.get(code, "The AI request could not be completed.")
