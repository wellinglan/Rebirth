from __future__ import annotations

import hashlib
import json
import time
import uuid
from dataclasses import dataclass
from typing import Literal

from pydantic import ValidationError
from sqlalchemy import case, or_, select, update
from sqlalchemy.dialects.postgresql import insert as postgresql_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.orm import Session

from app.models import Device, SyncClock, SyncItem
from app.schemas import (
    SyncAcceptedItem,
    SyncConflictResponse,
    PlanSyncPayload,
    JournalSyncPayload,
    TodaySyncPayload,
    SyncPullItem,
    SyncPullRequest,
    SyncPullResponse,
    SyncPushRequest,
    SyncPushResponse,
    OwnershipVerificationRequest,
    OwnershipVerificationResponse,
)


PROFILE_TABLE = "user_profiles"
TODAY_TABLE = "today_records"
JOURNAL_TABLE = "journal_entries"
GOALS_TABLE = "goals"
CANONICAL_PROFILE_RECORD_ID = "profile"
SYNC_CLOCK_ID = 1


class DeviceUnavailableError(RuntimeError):
    pass


class SyncRequestValidationError(ValueError):
    pass


def verify_ownership(
    session: Session,
    user_id: str,
    body: OwnershipVerificationRequest,
) -> OwnershipVerificationResponse:
    if not body.evidence:
        return OwnershipVerificationResponse(
            status="unknown",
            verified_count=0,
            rejected_count=0,
            unknown_count=0,
            reason="no_verifiable_evidence",
        )

    verified_count = 0
    rejected_count = 0
    unknown_count = 0
    seen: set[tuple[str, str, int]] = set()
    for evidence in body.evidence:
        key = (
            evidence.table_name,
            evidence.record_id,
            evidence.server_version,
        )
        if key in seen:
            raise SyncRequestValidationError("Duplicate ownership evidence.")
        seen.add(key)

        current_user_item = session.scalar(
            select(SyncItem).where(
                SyncItem.user_id == user_id,
                SyncItem.table_name == evidence.table_name,
                SyncItem.record_id == evidence.record_id,
            )
        )
        if current_user_item is not None:
            exact_current_match = (
                current_user_item.server_version == evidence.server_version
                and ownership_metadata_fingerprint(current_user_item)
                == evidence.metadata_fingerprint
            )
            if exact_current_match:
                verified_count += 1
            elif (
                evidence.table_name == "goals"
                and current_user_item.server_version > evidence.server_version
            ):
                # Goal UUIDs are stable record identities. A newer version under
                # the same JWT user is valid evidence that another owned device
                # advanced the record after this local snapshot.
                verified_count += 1
            elif (
                evidence.table_name == "user_profiles"
                and current_user_item.server_version > evidence.server_version
            ):
                other_profiles = session.scalars(
                    select(SyncItem).where(
                        SyncItem.user_id != user_id,
                        SyncItem.table_name == evidence.table_name,
                        SyncItem.record_id == evidence.record_id,
                        SyncItem.server_version == evidence.server_version,
                    )
                ).all()
                if any(
                    ownership_metadata_fingerprint(item)
                    == evidence.metadata_fingerprint
                    for item in other_profiles
                ):
                    rejected_count += 1
                else:
                    unknown_count += 1
            else:
                rejected_count += 1
            continue

        same_record_other_user = session.scalar(
            select(SyncItem).where(
                SyncItem.user_id != user_id,
                SyncItem.table_name == evidence.table_name,
                SyncItem.record_id == evidence.record_id,
            )
        )
        if evidence.table_name == "goals" and same_record_other_user is not None:
            rejected_count += 1
        else:
            exact_items = session.scalars(
                select(SyncItem).where(
                    SyncItem.user_id != user_id,
                    SyncItem.table_name == evidence.table_name,
                    SyncItem.record_id == evidence.record_id,
                    SyncItem.server_version == evidence.server_version,
                )
            ).all()
            if any(
                ownership_metadata_fingerprint(item)
                == evidence.metadata_fingerprint
                for item in exact_items
            ):
                rejected_count += 1
            else:
                unknown_count += 1

    if rejected_count > 0:
        return OwnershipVerificationResponse(
            status="rejected",
            verified_count=verified_count,
            rejected_count=rejected_count,
            unknown_count=unknown_count,
            reason="metadata_mismatch_or_other_owner",
        )
    if unknown_count > 0:
        return OwnershipVerificationResponse(
            status="unknown",
            verified_count=verified_count,
            rejected_count=0,
            unknown_count=unknown_count,
            reason="remote_record_missing",
        )
    return OwnershipVerificationResponse(
        status="verified",
        verified_count=verified_count,
        rejected_count=0,
        unknown_count=0,
        reason="all_evidence_matches_current_user",
    )


def ownership_metadata_fingerprint(item: SyncItem) -> str:
    canonical = json.dumps(
        {
            "deleted_at": item.deleted_at,
            "origin_device_id": item.origin_device_id,
            "record_id": item.record_id,
            "server_version": item.server_version,
            "table": item.table_name,
            "updated_at": item.client_updated_at,
        },
        ensure_ascii=True,
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


@dataclass
class _PreflightItem:
    incoming: object
    record_id: str
    payload_json: str
    existing: SyncItem | None
    outcome: Literal["write", "idempotent", "conflict"]
    conflict_reason: str | None = None
    remote_record_id: str | None = None
    conflict_server_version: int | None = None


def push(
    session: Session,
    user_id: str,
    body: SyncPushRequest,
) -> SyncPushResponse:
    _require_device(session, user_id, body.device_id)
    try:
        preflight = _preflight_push(session, user_id, body)
        stale_conflicts = [item for item in preflight if item.outcome == "conflict"]
        if stale_conflicts:
            accepted = [
                _accepted(item) for item in preflight if item.outcome == "idempotent"
            ]
            conflicts = [
                _conflict(item)
                if item.outcome == "conflict"
                else SyncConflictResponse(
                    table=item.incoming.table_name,
                    id=item.record_id,
                    server_version=(
                        item.existing.server_version
                        if item.existing is not None
                        else 0
                    ),
                    reason="request_conflict",
                )
                for item in preflight
                if item.outcome != "idempotent"
            ]
            session.rollback()
            return SyncPushResponse(accepted=accepted, conflicts=conflicts)

        accepted: list[SyncAcceptedItem] = []
        timestamp = time.time_ns() // 1_000_000
        for item in preflight:
            if item.outcome == "idempotent":
                accepted.append(_accepted(item))
                continue
            incoming = item.incoming
            server_version = _next_server_version(session)
            existing = item.existing
            if existing is None:
                existing = SyncItem(
                    id=str(uuid.uuid4()),
                    user_id=user_id,
                    table_name=incoming.table_name,
                    record_id=item.record_id,
                    payload_json=item.payload_json,
                    server_version=server_version,
                    client_updated_at=incoming.updated_at,
                    server_updated_at=timestamp,
                    deleted_at=incoming.deleted_at,
                    origin_device_id=incoming.origin_device_id,
                )
                session.add(existing)
            else:
                existing.payload_json = item.payload_json
                existing.server_version = server_version
                existing.client_updated_at = incoming.updated_at
                existing.server_updated_at = timestamp
                existing.deleted_at = incoming.deleted_at
                existing.origin_device_id = incoming.origin_device_id
            session.flush()
            accepted.append(
                SyncAcceptedItem(
                    table=incoming.table_name,
                    id=item.record_id,
                    server_version=server_version,
                )
            )

        session.commit()
    except Exception:
        session.rollback()
        raise
    return SyncPushResponse(accepted=accepted, conflicts=[])


def _preflight_push(
    session: Session,
    user_id: str,
    body: SyncPushRequest,
) -> list[_PreflightItem]:
    normalized_keys: set[tuple[str, str]] = set()
    preflight: list[_PreflightItem] = []

    for incoming in body.items:
        record_id = (
            CANONICAL_PROFILE_RECORD_ID
            if incoming.table_name == PROFILE_TABLE
            else incoming.record_id
        )
        key = (incoming.table_name, record_id)
        if key in normalized_keys:
            raise SyncRequestValidationError(
                f"Duplicate sync item: {incoming.table_name}/{record_id}."
            )
        normalized_keys.add(key)
        if incoming.table_name == GOALS_TABLE:
            _validate_goal_item(incoming, record_id)
        elif incoming.table_name == TODAY_TABLE:
            _validate_today_item(incoming, record_id)
        elif incoming.table_name == JOURNAL_TABLE:
            _validate_journal_item(incoming, record_id)

    _ensure_sync_clock(session)
    session.scalar(
        select(SyncClock).where(SyncClock.id == SYNC_CLOCK_ID).with_for_update()
    )
    table_names = {table_name for table_name, _ in normalized_keys}
    record_ids = {record_id for _, record_id in normalized_keys}
    existing_by_key = {
        (item.table_name, item.record_id): item
        for item in session.scalars(
            select(SyncItem)
            .where(
                SyncItem.user_id == user_id,
                SyncItem.table_name.in_(table_names),
                SyncItem.record_id.in_(record_ids),
            )
            .with_for_update()
        ).all()
    } if normalized_keys else {}

    for incoming in body.items:
        record_id = (
            CANONICAL_PROFILE_RECORD_ID
            if incoming.table_name == PROFILE_TABLE
            else incoming.record_id
        )
        existing = existing_by_key.get((incoming.table_name, record_id))
        payload_json = _canonical_payload(incoming.payload)
        if existing is None:
            outcome = "write" if incoming.client_version == 0 else "conflict"
            reason = None if outcome == "write" else "stale_client"
        elif _is_exact_replay(existing, incoming, payload_json):
            outcome = "idempotent"
            reason = None
        elif incoming.client_version == existing.server_version:
            outcome = "write"
            reason = None
        else:
            outcome = "conflict"
            reason = "stale_client"
        preflight.append(
            _PreflightItem(
                incoming=incoming,
                record_id=record_id,
                payload_json=payload_json,
                existing=existing,
                outcome=outcome,
                conflict_reason=reason,
            )
        )

    _validate_projected_goal_hierarchy(session, user_id, preflight)
    _validate_projected_today_dates(session, user_id, preflight)
    _validate_projected_journal_dates(session, user_id, preflight)
    return preflight


def _validate_goal_item(incoming: object, record_id: str) -> None:
    try:
        uuid.UUID(record_id)
        uuid.UUID(incoming.origin_device_id)
    except ValueError as error:
        raise SyncRequestValidationError(
            "Goal record and origin device IDs must be UUIDs."
        ) from error
    if incoming.deleted_at is not None:
        if incoming.payload:
            raise SyncRequestValidationError("Goal tombstone payload must be empty.")
        return
    try:
        payload = PlanSyncPayload.model_validate(incoming.payload)
    except (ValidationError, ValueError) as error:
        raise SyncRequestValidationError("Invalid Goal payload.") from error
    if payload.parent_goal_id == record_id:
        raise SyncRequestValidationError("Goal cannot be its own parent.")


def _validate_today_item(incoming: object, record_id: str) -> None:
    try:
        uuid.UUID(record_id)
        uuid.UUID(incoming.origin_device_id)
    except ValueError as error:
        raise SyncRequestValidationError(
            "Today record and origin device IDs must be UUIDs."
        ) from error
    if incoming.deleted_at is not None:
        if incoming.payload:
            raise SyncRequestValidationError("Today tombstone payload must be empty.")
        return
    try:
        TodaySyncPayload.model_validate(incoming.payload)
    except (ValidationError, ValueError) as error:
        raise SyncRequestValidationError("Invalid Today payload.") from error


def _validate_journal_item(incoming: object, record_id: str) -> None:
    try:
        uuid.UUID(record_id)
        uuid.UUID(incoming.origin_device_id)
    except ValueError as error:
        raise SyncRequestValidationError(
            "Journal record and origin device IDs must be UUIDs."
        ) from error
    if incoming.deleted_at is not None:
        if incoming.payload:
            raise SyncRequestValidationError(
                "Journal tombstone payload must be empty."
            )
        return
    try:
        JournalSyncPayload.model_validate(incoming.payload)
    except (ValidationError, ValueError) as error:
        raise SyncRequestValidationError("Invalid Journal payload.") from error


def _validate_projected_today_dates(
    session: Session,
    user_id: str,
    preflight: list[_PreflightItem],
) -> None:
    if not any(item.incoming.table_name == TODAY_TABLE for item in preflight):
        return
    current = session.scalars(
        select(SyncItem)
        .where(
            SyncItem.user_id == user_id,
            SyncItem.table_name == TODAY_TABLE,
        )
        .with_for_update()
    ).all()
    payload_by_id: dict[str, TodaySyncPayload] = {}
    current_by_id: dict[str, SyncItem] = {}
    for item in current:
        if item.deleted_at is not None:
            continue
        try:
            payload_by_id[item.record_id] = TodaySyncPayload.model_validate(
                json.loads(item.payload_json)
            )
            current_by_id[item.record_id] = item
        except (json.JSONDecodeError, ValidationError, ValueError) as error:
            raise SyncRequestValidationError(
                f"Stored Today {item.record_id} has invalid date data."
            ) from error

    owners = {
        payload.record_date: record_id
        for record_id, payload in payload_by_id.items()
    }
    for item in preflight:
        incoming = item.incoming
        if incoming.table_name != TODAY_TABLE or item.outcome == "conflict":
            continue
        if incoming.deleted_at is not None:
            previous = payload_by_id.pop(item.record_id, None)
            if previous is not None:
                owners.pop(previous.record_date, None)
            continue
        payload = TodaySyncPayload.model_validate(incoming.payload)
        previous = payload_by_id.get(item.record_id)
        if previous is not None and previous.record_date != payload.record_date:
            raise SyncRequestValidationError(
                "Today record_date cannot change after creation."
            )
        owner = owners.get(payload.record_date)
        if owner is not None and owner != item.record_id:
            remote = current_by_id[owner]
            item.outcome = "conflict"
            item.conflict_reason = "today_record_date_conflict"
            item.remote_record_id = owner
            item.conflict_server_version = remote.server_version
            continue
        if previous is not None:
            owners.pop(previous.record_date, None)
        payload_by_id[item.record_id] = payload
        owners[payload.record_date] = item.record_id


def _validate_projected_journal_dates(
    session: Session,
    user_id: str,
    preflight: list[_PreflightItem],
) -> None:
    if not any(item.incoming.table_name == JOURNAL_TABLE for item in preflight):
        return
    current = session.scalars(
        select(SyncItem)
        .where(
            SyncItem.user_id == user_id,
            SyncItem.table_name == JOURNAL_TABLE,
        )
        .with_for_update()
    ).all()
    payload_by_id: dict[str, JournalSyncPayload] = {}
    current_by_id: dict[str, SyncItem] = {}
    for item in current:
        if item.deleted_at is not None:
            continue
        try:
            payload_by_id[item.record_id] = JournalSyncPayload.model_validate(
                json.loads(item.payload_json)
            )
            current_by_id[item.record_id] = item
        except (json.JSONDecodeError, ValidationError, ValueError) as error:
            raise SyncRequestValidationError(
                f"Stored Journal {item.record_id} has invalid date data."
            ) from error

    owners = {
        payload.entry_date: record_id
        for record_id, payload in payload_by_id.items()
    }
    for item in preflight:
        incoming = item.incoming
        if incoming.table_name != JOURNAL_TABLE or item.outcome == "conflict":
            continue
        if incoming.deleted_at is not None:
            previous = payload_by_id.pop(item.record_id, None)
            if previous is not None:
                owners.pop(previous.entry_date, None)
            continue
        payload = JournalSyncPayload.model_validate(incoming.payload)
        previous = payload_by_id.get(item.record_id)
        if previous is not None and previous.entry_date != payload.entry_date:
            raise SyncRequestValidationError(
                "Journal entry_date cannot change after creation."
            )
        owner = owners.get(payload.entry_date)
        if owner is not None and owner != item.record_id:
            remote = current_by_id[owner]
            item.outcome = "conflict"
            item.conflict_reason = "journal_entry_date_conflict"
            item.remote_record_id = owner
            item.conflict_server_version = remote.server_version
            continue
        if previous is not None:
            owners.pop(previous.entry_date, None)
        payload_by_id[item.record_id] = payload
        owners[payload.entry_date] = item.record_id


def _validate_projected_goal_hierarchy(
    session: Session,
    user_id: str,
    preflight: list[_PreflightItem],
) -> None:
    if not any(item.incoming.table_name == GOALS_TABLE for item in preflight):
        return
    current = session.scalars(
        select(SyncItem)
        .where(
            SyncItem.user_id == user_id,
            SyncItem.table_name == GOALS_TABLE,
        )
        .with_for_update()
    ).all()
    parents: dict[str, str | None] = {}
    for item in current:
        if item.deleted_at is not None:
            continue
        try:
            payload = PlanSyncPayload.model_validate(json.loads(item.payload_json))
        except (json.JSONDecodeError, ValidationError, ValueError) as error:
            raise SyncRequestValidationError(
                f"Stored Goal {item.record_id} has invalid hierarchy data."
            ) from error
        parents[item.record_id] = payload.parent_goal_id

    for item in preflight:
        incoming = item.incoming
        if incoming.table_name != GOALS_TABLE:
            continue
        if incoming.deleted_at is not None:
            parents.pop(item.record_id, None)
            continue
        payload = PlanSyncPayload.model_validate(incoming.payload)
        parents[item.record_id] = payload.parent_goal_id

    for record_id, parent_id in parents.items():
        if parent_id is not None and parent_id not in parents:
            raise SyncRequestValidationError(
                f"Active Goal {record_id} references a missing parent."
            )

    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(record_id: str) -> None:
        if record_id in visited:
            return
        if record_id in visiting:
            raise SyncRequestValidationError("Goal hierarchy contains a cycle.")
        visiting.add(record_id)
        parent_id = parents[record_id]
        if parent_id is not None:
            visit(parent_id)
        visiting.remove(record_id)
        visited.add(record_id)

    for record_id in parents:
        visit(record_id)


def _canonical_payload(payload: dict[str, object]) -> str:
    return json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )


def _is_exact_replay(
    existing: SyncItem,
    incoming: object,
    payload_json: str,
) -> bool:
    try:
        stored_payload = json.loads(existing.payload_json)
        if not isinstance(stored_payload, dict):
            return False
        stored_payload_json = _canonical_payload(stored_payload)
    except (json.JSONDecodeError, TypeError):
        return False
    return (
        stored_payload_json == payload_json
        and existing.client_updated_at == incoming.updated_at
        and existing.deleted_at == incoming.deleted_at
        and existing.origin_device_id == incoming.origin_device_id
    )


def _accepted(item: _PreflightItem) -> SyncAcceptedItem:
    if item.existing is None:
        raise RuntimeError("An idempotent item must already exist.")
    return SyncAcceptedItem(
        table=item.incoming.table_name,
        id=item.record_id,
        server_version=item.existing.server_version,
    )


def _conflict(item: _PreflightItem) -> SyncConflictResponse:
    return SyncConflictResponse(
        table=item.incoming.table_name,
        id=item.record_id,
        server_version=(
            item.conflict_server_version
            if item.conflict_server_version is not None
            else item.existing.server_version if item.existing else 0
        ),
        reason=item.conflict_reason or "stale_client",
        remote_record_id=item.remote_record_id,
    )


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
