from __future__ import annotations

import json
import time
import uuid

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import Device, SyncItem
from app.schemas import (
    SyncAcceptedItem,
    SyncConflictResponse,
    SyncPullItem,
    SyncPullRequest,
    SyncPullResponse,
    SyncPushRequest,
    SyncPushResponse,
)


class DeviceUnavailableError(RuntimeError):
    pass


def push(
    session: Session,
    user_id: str,
    body: SyncPushRequest,
) -> SyncPushResponse:
    _require_device(session, user_id, body.device_id)
    accepted: list[SyncAcceptedItem] = []
    conflicts: list[SyncConflictResponse] = []

    for incoming in body.items:
        existing = session.scalar(
            select(SyncItem).where(
                SyncItem.user_id == user_id,
                SyncItem.table_name == incoming.table_name,
                SyncItem.record_id == incoming.record_id,
            )
        )
        if (
            existing is not None
            and incoming.client_version != existing.server_version
            and incoming.updated_at < existing.client_updated_at
        ):
            conflicts.append(
                SyncConflictResponse(
                    table=incoming.table_name,
                    id=incoming.record_id,
                    server_version=existing.server_version,
                    reason="stale_client",
                )
            )
            continue

        server_version = _next_server_version(session)
        timestamp = time.time_ns() // 1_000_000
        payload_json = json.dumps(
            incoming.payload,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )
        if existing is None:
            existing = SyncItem(
                id=str(uuid.uuid4()),
                user_id=user_id,
                table_name=incoming.table_name,
                record_id=incoming.record_id,
                payload_json=payload_json,
                server_version=server_version,
                client_updated_at=incoming.updated_at,
                server_updated_at=timestamp,
                deleted_at=incoming.deleted_at,
                origin_device_id=incoming.origin_device_id,
            )
            session.add(existing)
        else:
            existing.payload_json = payload_json
            existing.server_version = server_version
            existing.client_updated_at = incoming.updated_at
            existing.server_updated_at = timestamp
            existing.deleted_at = incoming.deleted_at
            existing.origin_device_id = incoming.origin_device_id
        session.flush()
        accepted.append(
            SyncAcceptedItem(
                table=incoming.table_name,
                id=incoming.record_id,
                server_version=server_version,
            )
        )

    session.commit()
    return SyncPushResponse(accepted=accepted, conflicts=conflicts)


def pull(
    session: Session,
    user_id: str,
    body: SyncPullRequest,
) -> SyncPullResponse:
    _require_device(session, user_id, body.device_id)
    records = session.scalars(
        select(SyncItem)
        .where(
            SyncItem.user_id == user_id,
            SyncItem.server_version > body.since_server_version,
            SyncItem.table_name.in_(body.tables),
        )
        .order_by(SyncItem.server_version)
    ).all()
    items = [
        SyncPullItem(
            table=record.table_name,
            id=record.record_id,
            payload=json.loads(record.payload_json),
            updated_at=record.client_updated_at,
            deleted_at=record.deleted_at,
            origin_device_id=record.origin_device_id,
            server_version=record.server_version,
        )
        for record in records
    ]
    return SyncPullResponse(
        server_version=_current_server_version(session),
        items=items,
    )


def _require_device(session: Session, user_id: str, device_id: str) -> Device:
    device = session.scalar(
        select(Device).where(
            Device.id == device_id,
            Device.user_id == user_id,
            Device.revoked_at.is_(None),
        )
    )
    if device is None:
        raise DeviceUnavailableError("Registered device not found.")
    return device


def _next_server_version(session: Session) -> int:
    return _current_server_version(session) + 1


def _current_server_version(session: Session) -> int:
    return session.scalar(select(func.coalesce(func.max(SyncItem.server_version), 0)))
