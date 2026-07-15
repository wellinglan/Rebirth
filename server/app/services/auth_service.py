from __future__ import annotations

import time
import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import AuthIdentity, CloudUser


def find_or_create_dev_user(session: Session, dev_user_key: str) -> CloudUser:
    identity = session.scalar(
        select(AuthIdentity).where(
            AuthIdentity.provider == "dev",
            AuthIdentity.provider_subject == dev_user_key,
        )
    )
    if identity is not None:
        return session.get_one(CloudUser, identity.user_id)

    timestamp = _utc_milliseconds()
    user = CloudUser(
        id=str(uuid.uuid4()),
        display_name=f"Dev {dev_user_key}"[:128],
        created_at=timestamp,
        updated_at=timestamp,
        deleted_at=None,
    )
    identity = AuthIdentity(
        id=str(uuid.uuid4()),
        user_id=user.id,
        provider="dev",
        provider_subject=dev_user_key,
        provider_union_id=None,
        created_at=timestamp,
        updated_at=timestamp,
    )
    session.add(user)
    session.flush()
    session.add(identity)
    session.commit()
    return user


def _utc_milliseconds() -> int:
    return time.time_ns() // 1_000_000
