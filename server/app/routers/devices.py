from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_session
from app.schemas import DeviceRegisterRequest, DeviceRegisterResponse
from app.security import require_user_id
from app.services.device_service import register_device


router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("/register", response_model=DeviceRegisterResponse)
def register(
    body: DeviceRegisterRequest,
    user_id: str = Depends(require_user_id),
    session: Session = Depends(get_session),
) -> DeviceRegisterResponse:
    device, server_time = register_device(session, user_id, body)
    return DeviceRegisterResponse(device_id=device.id, server_time=server_time)
