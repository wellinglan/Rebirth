from __future__ import annotations

import json
import time
import uuid

from sqlalchemy import case, or_, select, update
from sqlalchemy.dialects.postgresql import insert as postgresql_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.orm import Session

from app.models import Device, SyncClock, SyncItem
from app.schemas import (
    SyncAcceptedItem,
    SyncConflictResponse,
    SyncPullItem,
    SyncPullRequest,
    SyncPullResponse,
    SyncPushRequest,
    SyncPushResponse,
)


PROFILE_TABLE = "user_profiles"
CANONICAL_PROFILE_RECORD_ID = "profile"
SYNC_CLOCK_ID = 1


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

    try:
        for incoming in body.items:
            record_id = (
                CANONICAL_PROFILE_RECORD_ID
                if incoming.table_name == PROFILE_TABLE
                else incoming.record_id
            )
            if incoming.table_name == PROFILE_TABLE:
                _ensure_canonical_profile(session, user_id)
            existing = session.scalar(
                select(SyncItem).where(
                    SyncItem.user_id == user_id,
                    SyncItem.table_name == incoming.table_name,
                    SyncItem.record_id == record_id,
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
                        id=record_id,
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
                    record_id=record_id,
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
                    id=record_id,
                    server_version=server_version,
                )
            )

        session.commit()
    except Exception:
        session.rollback()
        raise
    return SyncPushResponse(accepted=accepted, conflicts=conflicts)


def pull(
    session: Session,
    user_id: str,
    body: SyncPullRequest,
) -> SyncPullResponse:
    _require_device(session, user_id, body.device_id)
    if PROFILE_TABLE in body.tables:
        try:
            _, migrated = _ensure_canonical_profile(session, user_id)
            if migrated:
                session.commit()
        except Exception:
            session.rollback()
            raise

    records = session.scalars(
        select(SyncItem)
        .where(
            SyncItem.user_id == user_id,
            SyncItem.server_version > body.since_server_version,
            SyncItem.table_name.in_(body.tables),
            or_(
                SyncItem.table_name != PROFILE_TABLE,
                SyncItem.record_id == CANONICAL_PROFILE_RECORD_ID,
            ),
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


def _ensure_canonical_profile(
    session: Session,
    user_id: str,
) -> tuple[SyncItem | None, bool]:
    canonical = session.scalar(
        select(SyncItem).where(
            SyncItem.user_id == user_id,
            SyncItem.table_name == PROFILE_TABLE,
            SyncItem.record_id == CANONICAL_PROFILE_RECORD_ID,
        )
    )
    if canonical is not None:
        return canonical, False

    legacy = session.scalar(
        select(SyncItem)
        .where(
            SyncItem.user_id == user_id,
            SyncItem.table_name == PROFILE_TABLE,
            SyncItem.record_id != CANONICAL_PROFILE_RECORD_ID,
            SyncItem.deleted_at.is_(None),
        )
        .order_by(SyncItem.server_version.desc())
        .limit(1)
    )
    if legacy is None:
        return None, False

    server_version = _next_server_version(session)
    values = {
        "id": str(uuid.uuid4()),
        "user_id": user_id,
        "table_name": PROFILE_TABLE,
        "record_id": CANONICAL_PROFILE_RECORD_ID,
        "payload_json": legacy.payload_json,
        "server_version": server_version,
        "client_updated_at": legacy.client_updated_at,
        "server_updated_at": time.time_ns() // 1_000_000,
        "deleted_at": None,
        "origin_device_id": legacy.origin_device_id,
    }
    dialect = session.bind.dialect.name
    if dialect == "postgresql":
        statement = postgresql_insert(SyncItem).values(**values)
        statement = statement.on_conflict_do_nothing(
            constraint="uq_sync_item_user_table_record"
        )
    elif dialect == "sqlite":
        statement = sqlite_insert(SyncItem).values(**values)
        statement = statement.on_conflict_do_nothing(
            index_elements=["user_id", "table_name", "record_id"]
        )
    else:
        raise RuntimeError(f"Unsupported sync database dialect: {dialect}")
    result = session.execute(statement)
    inserted = result.rowcount == 1
    if not inserted:
        # Another worker won the canonical insert. Roll back this transaction's
        # unused clock allocation so pull never exposes an uncommitted cursor.
        session.rollback()
        canonical = session.scalar(
            select(SyncItem).where(
                SyncItem.user_id == user_id,
                SyncItem.table_name == PROFILE_TABLE,
                SyncItem.record_id == CANONICAL_PROFILE_RECORD_ID,
            )
        )
        return canonical, False
    session.flush()
    canonical = session.scalar(
        select(SyncItem).where(
            SyncItem.user_id == user_id,
            SyncItem.table_name == PROFILE_TABLE,
            SyncItem.record_id == CANONICAL_PROFILE_RECORD_ID,
        )
    )
    return canonical, True


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
    _ensure_sync_clock(session)
    version = session.scalar(
        update(SyncClock)
        .where(SyncClock.id == SYNC_CLOCK_ID)
        .values(current_version=SyncClock.current_version + 1)
        .returning(SyncClock.current_version)
    )
    if version is None:
        raise RuntimeError("Sync clock is unavailable.")
    return version


def _current_server_version(session: Session) -> int:
    clock_version = session.scalar(
        select(SyncClock.current_version).where(SyncClock.id == SYNC_CLOCK_ID)
    )
    if clock_version is not None:
        return clock_version
    return _max_item_version(session)


def _ensure_sync_clock(session: Session) -> None:
    maximum = _max_item_version(session)
    values = {"id": SYNC_CLOCK_ID, "current_version": maximum}
    dialect = session.bind.dialect.name
    if dialect == "postgresql":
        statement = postgresql_insert(SyncClock).values(**values)
        statement = statement.on_conflict_do_nothing(index_elements=["id"])
    elif dialect == "sqlite":
        statement = sqlite_insert(SyncClock).values(**values)
        statement = statement.on_conflict_do_nothing(index_elements=["id"])
    else:
        raise RuntimeError(f"Unsupported sync database dialect: {dialect}")
    session.execute(statement)
    session.execute(
        update(SyncClock)
        .where(SyncClock.id == SYNC_CLOCK_ID)
        .values(
            current_version=case(
                (SyncClock.current_version < maximum, maximum),
                else_=SyncClock.current_version,
            )
        )
    )
    session.flush()


def _max_item_version(session: Session) -> int:
    latest = session.scalar(
        select(SyncItem.server_version)
        .order_by(SyncItem.server_version.desc())
        .limit(1)
    )
    return latest or 0
