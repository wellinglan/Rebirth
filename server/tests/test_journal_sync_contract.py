from __future__ import annotations

from fastapi.testclient import TestClient


JOURNAL_ID = "41111111-1111-4111-8111-111111111111"
SECOND_JOURNAL_ID = "42222222-2222-4222-8222-222222222222"
ORIGIN_ID = "43333333-3333-4333-8333-333333333333"


def _payload(
    *,
    entry_date: str = "2026-07-28",
    learning: str | None = "Typed Journal sync",
) -> dict[str, object]:
    return {
        "entry_date": entry_date,
        "timezone_offset_minutes": 480,
        "most_important_accomplishment": "Finished the sync contract",
        "most_draining_event": None,
        "emotion_source": None,
        "learning": learning,
        "tomorrow_adjustment": None,
        "entry_status": "completed",
        "created_at": 1_785_196_000_000,
    }


def _item(
    *,
    record_id: str = JOURNAL_ID,
    payload: dict[str, object] | None = None,
    client_version: int = 0,
    updated_at: int = 1_785_196_800_000,
    deleted_at: int | None = None,
) -> dict[str, object]:
    return {
        "table": "journal_entries",
        "id": record_id,
        "payload": payload if payload is not None else _payload(),
        "updated_at": updated_at,
        "deleted_at": deleted_at,
        "origin_device_id": ORIGIN_ID,
        "client_version": client_version,
    }


def _push(
    client: TestClient,
    headers: dict[str, str],
    device_id: str,
    item: dict[str, object],
):
    return client.post(
        "/sync/push",
        headers=headers,
        json={"device_id": device_id, "items": [item]},
    )


def test_journal_create_retry_and_pull_are_typed_and_idempotent(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    item = _item()
    first = _push(client, auth_headers, registered_device, item)
    retry = _push(client, auth_headers, registered_device, item)

    assert first.status_code == 200
    assert retry.status_code == 200
    version = first.json()["accepted"][0]["server_version"]
    assert retry.json()["accepted"][0]["server_version"] == version
    pulled = client.post(
        "/sync/pull",
        headers=auth_headers,
        json={
            "device_id": registered_device,
            "since_server_version": 0,
            "tables": ["journal_entries"],
        },
    )
    assert pulled.status_code == 200
    assert pulled.json()["items"][0]["payload"] == _payload()


def test_journal_rejects_invalid_or_empty_payload(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    invalid = _payload()
    invalid["entry_status"] = "published"
    empty = _payload(learning=None)
    empty["most_important_accomplishment"] = None

    invalid_response = _push(
        client,
        auth_headers,
        registered_device,
        _item(payload=invalid),
    )
    empty_response = _push(
        client,
        auth_headers,
        registered_device,
        _item(record_id=SECOND_JOURNAL_ID, payload=empty),
    )

    assert invalid_response.status_code == 422
    assert empty_response.status_code == 422


def test_journal_tombstone_requires_an_empty_payload(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    created = _push(client, auth_headers, registered_device, _item())
    version = created.json()["accepted"][0]["server_version"]
    rejected = _push(
        client,
        auth_headers,
        registered_device,
        _item(
            payload=_payload(),
            client_version=version,
            updated_at=1_785_196_900_000,
            deleted_at=1_785_196_900_000,
        ),
    )
    accepted = _push(
        client,
        auth_headers,
        registered_device,
        _item(
            payload={},
            client_version=version,
            updated_at=1_785_196_900_000,
            deleted_at=1_785_196_900_000,
        ),
    )

    assert rejected.status_code == 422
    assert accepted.status_code == 200


def test_journal_returns_structured_conflict_for_second_identity_on_same_date(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    first = _push(client, auth_headers, registered_device, _item())
    second = _push(
        client,
        auth_headers,
        registered_device,
        _item(record_id=SECOND_JOURNAL_ID),
    )

    assert first.status_code == 200
    assert second.status_code == 200
    assert second.json()["accepted"] == []
    assert second.json()["conflicts"] == [
        {
            "table": "journal_entries",
            "id": SECOND_JOURNAL_ID,
            "server_version": first.json()["accepted"][0]["server_version"],
            "reason": "journal_entry_date_conflict",
            "remote_record_id": JOURNAL_ID,
        }
    ]


def test_journal_entry_date_is_immutable_and_stale_occ_conflicts(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    created = _push(client, auth_headers, registered_device, _item())
    version = created.json()["accepted"][0]["server_version"]
    changed = _push(
        client,
        auth_headers,
        registered_device,
        _item(
            payload=_payload(entry_date="2026-07-29"),
            client_version=version,
            updated_at=1_785_283_200_000,
        ),
    )
    stale = _push(
        client,
        auth_headers,
        registered_device,
        _item(
            payload=_payload(learning="Stale local edit"),
            client_version=0,
            updated_at=1_785_283_300_000,
        ),
    )

    assert changed.status_code == 422
    assert stale.status_code == 200
    assert stale.json()["accepted"] == []
    assert stale.json()["conflicts"][0]["server_version"] == version


def test_journal_pull_is_isolated_by_jwt_user(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    assert _push(client, auth_headers, registered_device, _item()).status_code == 200
    login = client.post(
        "/auth/dev-login",
        json={"dev_user_key": "journal-other-user"},
    )
    other_headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
    registration = client.post(
        "/devices/register",
        headers=other_headers,
        json={
            "local_installation_id": "journal-other-installation",
            "platform": "android",
            "device_name": "Other Journal device",
            "app_version": "1.0.0+1",
        },
    )
    pulled = client.post(
        "/sync/pull",
        headers=other_headers,
        json={
            "device_id": registration.json()["device_id"],
            "since_server_version": 0,
            "tables": ["journal_entries"],
        },
    )

    assert pulled.status_code == 200
    assert pulled.json()["items"] == []
