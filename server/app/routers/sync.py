from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_session
from app.schemas import (
    SyncPullRequest,
    SyncPullResponse,
    SyncPushRequest,
    SyncPushResponse,
)
from app.security import require_user_id
from app.services.sync_service import DeviceUnavailableError, pull, push


router = APIRouter(prefix="/sync", tags=["sync"])


@router.post("/push", response_model=SyncPushResponse)
def push_items(
    body: SyncPushRequest,
    user_id: str = Depends(require_user_id),
    session: Session = Depends(get_session),
) -> SyncPushResponse:
    try:
        return push(session, user_id, body)
    except DeviceUnavailableError as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(error),
        ) from error


@router.post("/pull", response_model=SyncPullResponse)
def pull_items(
    body: SyncPullRequest,
    user_id: str = Depends(require_user_id),
    session: Session = Depends(get_session),
) -> SyncPullResponse:
    try:
        return pull(session, user_id, body)
    except DeviceUnavailableError as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(error),
        ) from error
