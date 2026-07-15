from __future__ import annotations

import time
import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Device
from app.schemas import DeviceRegisterRequest


def register_device(
    session: Session,
    user_id: str,
    body: DeviceRegisterRequest,
) -> tuple[Device, int]:
    timestamp = time.time_ns() // 1_000_000
    device = session.scalar(
        select(Device).where(
            Device.user_id == user_id,
            Device.local_installation_id == body.local_installation_id,
        )
    )
    if device is None:
        device = Device(
            id=str(uuid.uuid4()),
            user_id=user_id,
            local_installation_id=body.local_installation_id,
            platform=body.platform,
            device_name=body.device_name,
            app_version=body.app_version,
            created_at=timestamp,
            last_seen_at=timestamp,
            revoked_at=None,
        )
        session.add(device)
    else:
        device.platform = body.platform
        device.device_name = body.device_name
        device.app_version = body.app_version
        device.last_seen_at = timestamp
    session.commit()
    return device, timestamp
