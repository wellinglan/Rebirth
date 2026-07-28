from __future__ import annotations

import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.models import SyncClock, SyncItem


PARENT_ID = "11111111-1111-4111-8111-111111111111"
CHILD_ID = "22222222-2222-4222-8222-222222222222"


def _goal_payload(
    title: str,
    *,
    parent_id: str | None = None,
    status: str = "not_started",
    completed_at: int | None = None,
) -> dict[str, object]:
    return {
        "parent_goal_id": parent_id,
        "title": title,
        "description": None,
        "goal_level": "year",
        "status": status,
        "start_date": "2026-01-01",
        "target_date": "2026-12-31",
        "completed_at": completed_at,
        "archived_at": None,
        "sort_order": 0,
        "created_at": 1_784_160_000_000,
    }


def _item(
    table: str,
    record_id: str,
    payload: dict[str, object],
    *,
    client_version: int = 0,
    updated_at: int = 1_784_160_000_000,
    deleted_at: int | None = None,
) -> dict[str, object]:
    return {
        "table": table,
        "id": record_id,
        "payload": payload,
        "updated_at": updated_at,
        "deleted_at": deleted_at,
        "origin_device_id": "33333333-3333-4333-8333-333333333333",
        "client_version": client_version,
    }


def _push(
    client: TestClient,
    headers: dict[str, str],
    device_id: str,
    items: list[dict[str, object]],
):
    return client.post(
        "/sync/push",
        headers=headers,
        json={"device_id": device_id, "items": items},
    )


def test_stale_client_cannot_win_with_a_newer_client_timestamp(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    first = _item(
        "journal_entries",
        "strict-record",
        {"daily_note": "cloud"},
    )
    created = _push(client, auth_headers, registered_device, [first])
    assert created.status_code == 200
    version = created.json()["accepted"][0]["server_version"]

    stale = _item(
        "journal_entries",
        "strict-record",
        {"daily_note": "stale but newer clock"},
        updated_at=first["updated_at"] + 999_999,
        client_version=0,
    )
    response = _push(client, auth_headers, registered_device, [stale])

    assert response.status_code == 200
    assert response.json()["accepted"] == []
    assert response.json()["conflicts"][0]["reason"] == "stale_client"
    assert response.json()["conflicts"][0]["server_version"] == version
    pulled = client.post(
        "/sync/pull",
        headers=auth_headers,
        json={
            "device_id": registered_device,
            "since_server_version": 0,
            "tables": ["journal_entries"],
        },
    )
    assert pulled.json()["items"][0]["payload"]["daily_note"] == "cloud"
    assert pulled.json()["server_version"] == version


@pytest.mark.parametrize("timestamp_delta", [-1, 0, 1])
def test_stale_client_conflicts_regardless_of_client_timestamp(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
    timestamp_delta: int,
) -> None:
    timestamp = 1_784_160_000_000
    created = _push(
        client,
        auth_headers,
        registered_device,
        [
            _item(
                "journal_entries",
                "timestamp-record",
                {"value": "cloud"},
                updated_at=timestamp,
            )
        ],
    )
    version = created.json()["accepted"][0]["server_version"]

    stale = _push(
        client,
        auth_headers,
        registered_device,
        [
            _item(
                "journal_entries",
                "timestamp-record",
                {"value": "stale"},
                updated_at=timestamp + timestamp_delta,
                client_version=0,
            )
        ],
    )

    assert stale.json()["accepted"] == []
    assert stale.json()["conflicts"][0]["server_version"] == version


def test_matching_client_version_updates_an_existing_record(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    created = _push(
        client,
        auth_headers,
        registered_device,
        [_item("journal_entries", "matching-version", {"value": "first"})],
    )
    first_version = created.json()["accepted"][0]["server_version"]

    updated = _push(
        client,
        auth_headers,
        registered_device,
        [
            _item(
                "journal_entries",
                "matching-version",
                {"value": "second"},
                client_version=first_version,
                updated_at=1_784_160_001_000,
            )
        ],
    )

    assert updated.json()["conflicts"] == []
    assert updated.json()["accepted"][0]["server_version"] > first_version


def test_new_record_with_nonzero_client_version_is_a_conflict(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    response = _push(
        client,
        auth_headers,
        registered_device,
        [
            _item(
                "journal_entries",
                "invalid-new-baseline",
                {"value": "new"},
                client_version=9,
            )
        ],
    )

    assert response.json()["accepted"] == []
    assert response.json()["conflicts"][0]["reason"] == "stale_client"
    with client.app.state.database.session_factory() as session:
        assert session.scalar(select(SyncItem)) is None
        assert session.scalar(select(SyncClock.current_version)) is None


def test_exact_retry_is_idempotent_and_does_not_touch_server_clock_or_timestamp(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    item = _item("journal_entries", "idempotent-record", {"daily_note": "same"})
    first = _push(client, auth_headers, registered_device, [item])
    version = first.json()["accepted"][0]["server_version"]
    database = client.app.state.database
    with database.session_factory() as session:
        before = session.scalar(
            select(SyncItem).where(SyncItem.record_id == "idempotent-record")
        )
        assert before is not None
        server_updated_at = before.server_updated_at

    retry = _push(client, auth_headers, registered_device, [item])

    assert retry.status_code == 200
    assert retry.json()["accepted"][0]["server_version"] == version
    assert retry.json()["conflicts"] == []
    with database.session_factory() as session:
        after = session.scalar(
            select(SyncItem).where(SyncItem.record_id == "idempotent-record")
        )
        assert after is not None
        assert after.server_updated_at == server_updated_at
        assert session.scalar(select(SyncClock.current_version)) == version


def test_conflicting_push_batch_is_atomic_and_does_not_advance_clock(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    first = _item("journal_entries", "existing-record", {"value": "cloud"})
    created = _push(client, auth_headers, registered_device, [first])
    version = created.json()["accepted"][0]["server_version"]
    stale = _item(
        "journal_entries",
        "existing-record",
        {"value": "stale"},
        client_version=0,
    )
    new_item = _item("journal_entries", "must-not-write", {"value": "new"})

    response = _push(
        client,
        auth_headers,
        registered_device,
        [stale, new_item],
    )

    assert response.status_code == 200
    assert response.json()["accepted"] == []
    assert {item["reason"] for item in response.json()["conflicts"]} == {
        "stale_client",
        "request_conflict",
    }
    with client.app.state.database.session_factory() as session:
        assert (
            session.scalar(
                select(SyncItem).where(SyncItem.record_id == "must-not-write")
            )
            is None
        )
        assert session.scalar(select(SyncClock.current_version)) == version


def test_duplicate_normalized_record_in_one_request_is_rejected(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    item = _item("journal_entries", "duplicate-record", {"value": 1})

    response = _push(client, auth_headers, registered_device, [item, item])

    assert response.status_code == 422
    with client.app.state.database.session_factory() as session:
        assert session.scalar(select(SyncItem)) is None


def test_goal_parent_and_child_can_be_created_in_one_atomic_batch(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    child = _item(
        "goals",
        CHILD_ID,
        _goal_payload("Child", parent_id=PARENT_ID),
    )
    parent = _item("goals", PARENT_ID, _goal_payload("Parent"))

    response = _push(
        client,
        auth_headers,
        registered_device,
        [child, parent],
    )

    assert response.status_code == 200
    assert response.json()["conflicts"] == []
    assert {item["id"] for item in response.json()["accepted"]} == {
        PARENT_ID,
        CHILD_ID,
    }


def test_goal_cycle_is_rejected_without_writes_or_clock_advance(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    first = _item(
        "goals",
        PARENT_ID,
        _goal_payload("First", parent_id=CHILD_ID),
    )
    second = _item(
        "goals",
        CHILD_ID,
        _goal_payload("Second", parent_id=PARENT_ID),
    )

    response = _push(
        client,
        auth_headers,
        registered_device,
        [first, second],
    )

    assert response.status_code == 422
    with client.app.state.database.session_factory() as session:
        assert session.scalars(
            select(SyncItem).where(SyncItem.table_name == "goals")
        ).all() == []
        assert session.scalar(select(SyncClock.current_version)) is None


def test_parent_tombstone_requires_the_active_child_tombstone(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    created = _push(
        client,
        auth_headers,
        registered_device,
        [
            _item("goals", PARENT_ID, _goal_payload("Parent")),
            _item(
                "goals",
                CHILD_ID,
                _goal_payload("Child", parent_id=PARENT_ID),
            ),
        ],
    )
    versions = {
        item["id"]: item["server_version"] for item in created.json()["accepted"]
    }
    deleted_at = 1_784_160_100_000
    parent_only = _item(
        "goals",
        PARENT_ID,
        {},
        client_version=versions[PARENT_ID],
        updated_at=deleted_at,
        deleted_at=deleted_at,
    )

    rejected = _push(
        client,
        auth_headers,
        registered_device,
        [parent_only],
    )

    assert rejected.status_code == 422
    with client.app.state.database.session_factory() as session:
        parent = session.scalar(
            select(SyncItem).where(SyncItem.record_id == PARENT_ID)
        )
        assert parent is not None
        assert parent.deleted_at is None
        assert session.scalar(select(SyncClock.current_version)) == max(
            versions.values()
        )


def test_complete_goal_subtree_tombstone_is_atomic(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    created = _push(
        client,
        auth_headers,
        registered_device,
        [
            _item("goals", PARENT_ID, _goal_payload("Parent")),
            _item(
                "goals",
                CHILD_ID,
                _goal_payload("Child", parent_id=PARENT_ID),
            ),
        ],
    )
    versions = {
        item["id"]: item["server_version"] for item in created.json()["accepted"]
    }
    deleted_at = 1_784_160_100_000

    deleted = _push(
        client,
        auth_headers,
        registered_device,
        [
            _item(
                "goals",
                PARENT_ID,
                {},
                client_version=versions[PARENT_ID],
                updated_at=deleted_at,
                deleted_at=deleted_at,
            ),
            _item(
                "goals",
                CHILD_ID,
                {},
                client_version=versions[CHILD_ID],
                updated_at=deleted_at,
                deleted_at=deleted_at,
            ),
        ],
    )

    assert deleted.status_code == 200
    assert deleted.json()["conflicts"] == []
    with client.app.state.database.session_factory() as session:
        rows = session.scalars(
            select(SyncItem).where(SyncItem.table_name == "goals")
        ).all()
        assert len(rows) == 2
        assert all(row.deleted_at == deleted_at for row in rows)


def test_invalid_goal_identity_and_payload_do_not_write(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    invalid_id = _item("goals", "not-a-uuid", _goal_payload("Invalid"))
    invalid_date = _item(
        "goals",
        str(uuid.uuid4()),
        {
            **_goal_payload("Invalid date"),
            "target_date": "2026-02-30",
        },
    )

    assert (
        _push(client, auth_headers, registered_device, [invalid_id]).status_code
        == 422
    )
    assert (
        _push(client, auth_headers, registered_device, [invalid_date]).status_code
        == 422
    )
    with client.app.state.database.session_factory() as session:
        assert session.scalars(
            select(SyncItem).where(SyncItem.table_name == "goals")
        ).all() == []


def test_goal_payload_business_validation_rejects_invalid_variants(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    valid = _goal_payload("Private valid title")
    invalid_payloads = [
        {**valid, "parent_goal_id": "bad-parent"},
        {**valid, "title": "   "},
        {**valid, "goal_level": "decade"},
        {**valid, "status": "unknown"},
        {**valid, "start_date": "2026-13-01"},
        {**valid, "start_date": "2026-12-31", "target_date": "2026-01-01"},
        {**valid, "completed_at": -1},
        {**valid, "archived_at": -1},
        {**valid, "sort_order": -1},
        {**valid, "created_at": -1},
    ]
    for index, payload in enumerate(invalid_payloads):
        response = _push(
            client,
            auth_headers,
            registered_device,
            [_item("goals", str(uuid.uuid4()), payload)],
        )
        assert response.status_code == 422, index
        assert "Private valid title" not in response.text
    missing_parent = _push(
        client,
        auth_headers,
        registered_device,
        [
            _item(
                "goals",
                str(uuid.uuid4()),
                _goal_payload("Orphan", parent_id=str(uuid.uuid4())),
            )
        ],
    )
    assert missing_parent.status_code == 422
    self_id = str(uuid.uuid4())
    self_parent = _push(
        client,
        auth_headers,
        registered_device,
        [
            _item(
                "goals",
                self_id,
                _goal_payload("Self", parent_id=self_id),
            )
        ],
    )
    assert self_parent.status_code == 422


def test_plan_records_are_isolated_by_jwt_owner_and_ignore_payload_user_id(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    payload = {**_goal_payload("User A private"), "user_id": "forged-owner"}
    created = _push(
        client,
        auth_headers,
        registered_device,
        [_item("goals", PARENT_ID, payload)],
    )
    assert created.status_code == 200

    login = client.post("/auth/dev-login", json={"dev_user_key": "plan-user-b"})
    other_headers = {
        "Authorization": f"Bearer {login.json()['access_token']}"
    }
    registration = client.post(
        "/devices/register",
        headers=other_headers,
        json={
            "local_installation_id": "plan-user-b-installation",
            "platform": "android",
            "device_name": "Plan user B",
            "app_version": "1.0.0+1",
        },
    )
    other_device = registration.json()["device_id"]
    pulled = client.post(
        "/sync/pull",
        headers=other_headers,
        json={
            "device_id": other_device,
            "since_server_version": 0,
            "tables": ["goals"],
        },
    )

    assert pulled.status_code == 200
    assert pulled.json()["items"] == []
    other_created = _push(
        client,
        other_headers,
        other_device,
        [_item("goals", PARENT_ID, _goal_payload("User B own copy"))],
    )
    assert other_created.status_code == 200
