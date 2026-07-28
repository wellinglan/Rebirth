from __future__ import annotations

from fastapi.testclient import TestClient


TODAY_ID = "11111111-1111-4111-8111-111111111111"
SECOND_TODAY_ID = "22222222-2222-4222-8222-222222222222"
ORIGIN_ID = "33333333-3333-4333-8333-333333333333"


def _payload(
    *,
    record_date: str = "2026-07-28",
    daily_note: str | None = "Today cloud",
) -> dict[str, object]:
    return {
        "record_date": record_date,
        "timezone_offset_minutes": 480,
        "priority_1": "Research",
        "priority_1_completed": True,
        "priority_1_goal_id": None,
        "priority_2": None,
        "priority_2_completed": False,
        "priority_2_goal_id": None,
        "priority_3": None,
        "priority_3_completed": False,
        "priority_3_goal_id": None,
        "mood_score": 4,
        "energy_score": 3,
        "research_minutes": 90,
        "learning_minutes": 0,
        "daily_note": daily_note,
        "record_status": "completed",
        "created_at": 1_785_196_000_000,
    }


def _item(
    *,
    record_id: str = TODAY_ID,
    payload: dict[str, object] | None = None,
    client_version: int = 0,
    updated_at: int = 1_785_196_800_000,
    deleted_at: int | None = None,
) -> dict[str, object]:
    return {
        "table": "today_records",
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


def test_today_create_retry_and_pull_are_typed_and_idempotent(
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
            "tables": ["today_records"],
        },
    )
    assert pulled.status_code == 200
    assert pulled.json()["items"][0]["payload"] == _payload()


def test_today_rejects_invalid_payload_without_advancing_sync(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    invalid = _payload()
    invalid["mood_score"] = 6

    response = _push(
        client,
        auth_headers,
        registered_device,
        _item(payload=invalid),
    )

    assert response.status_code == 422
    assert "Today cloud" not in response.text


def test_today_tombstone_requires_an_empty_payload(
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


def test_today_rejects_a_second_active_record_for_the_same_date(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    first = _push(client, auth_headers, registered_device, _item())
    second = _push(
        client,
        auth_headers,
        registered_device,
        _item(record_id=SECOND_TODAY_ID),
    )

    assert first.status_code == 200
    assert second.status_code == 422
    pulled = client.post(
        "/sync/pull",
        headers=auth_headers,
        json={
            "device_id": registered_device,
            "since_server_version": 0,
            "tables": ["today_records"],
        },
    )
    assert len(pulled.json()["items"]) == 1


def test_today_record_date_is_immutable(
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
            payload=_payload(record_date="2026-07-29"),
            client_version=version,
            updated_at=1_785_283_200_000,
        ),
    )

    assert changed.status_code == 422


def test_today_pull_is_isolated_by_jwt_user(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    assert _push(client, auth_headers, registered_device, _item()).status_code == 200
    login = client.post(
        "/auth/dev-login",
        json={"dev_user_key": "today-other-user"},
    )
    other_headers = {
        "Authorization": f"Bearer {login.json()['access_token']}"
    }
    registration = client.post(
        "/devices/register",
        headers=other_headers,
        json={
            "local_installation_id": "today-other-installation",
            "platform": "android",
            "device_name": "Other Today device",
            "app_version": "1.0.0+1",
        },
    )

    pulled = client.post(
        "/sync/pull",
        headers=other_headers,
        json={
            "device_id": registration.json()["device_id"],
            "since_server_version": 0,
            "tables": ["today_records"],
        },
    )

    assert pulled.status_code == 200
    assert pulled.json()["items"] == []
