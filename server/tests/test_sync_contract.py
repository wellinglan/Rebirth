from fastapi.testclient import TestClient


def _push_body(
    device_id: str,
    *,
    updated_at: int = 1_784_073_600_000,
    deleted_at: int | None = None,
    client_version: int = 0,
) -> dict[str, object]:
    return {
        "device_id": device_id,
        "items": [
            {
                "table": "today_records",
                "id": "today-record-1",
                "payload": {
                    "record_date": "2026-07-15",
                    "daily_note": "Foundation test",
                },
                "updated_at": updated_at,
                "deleted_at": deleted_at,
                "origin_device_id": "pytest-installation",
                "client_version": client_version,
            }
        ],
    }


def _pull_body(device_id: str, since: int) -> dict[str, object]:
    return {
        "device_id": device_id,
        "since_server_version": since,
        "tables": ["today_records"],
    }


def test_sync_push_accepts_today_record(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    response = client.post(
        "/sync/push",
        headers=auth_headers,
        json=_push_body(registered_device),
    )

    assert response.status_code == 200
    assert response.json()["conflicts"] == []
    assert response.json()["accepted"][0]["table"] == "today_records"
    assert response.json()["accepted"][0]["server_version"] == 1


def test_sync_pull_returns_pushed_item(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    pushed = client.post(
        "/sync/push",
        headers=auth_headers,
        json=_push_body(registered_device),
    )
    assert pushed.status_code == 200

    response = client.post(
        "/sync/pull",
        headers=auth_headers,
        json=_pull_body(registered_device, 0),
    )

    assert response.status_code == 200
    assert response.json()["server_version"] == 1
    assert response.json()["items"][0]["id"] == "today-record-1"
    assert response.json()["items"][0]["payload"]["daily_note"] == "Foundation test"


def test_since_server_version_filters_old_item(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    pushed = client.post(
        "/sync/push",
        headers=auth_headers,
        json=_push_body(registered_device),
    )
    version = pushed.json()["accepted"][0]["server_version"]

    response = client.post(
        "/sync/pull",
        headers=auth_headers,
        json=_pull_body(registered_device, version),
    )

    assert response.status_code == 200
    assert response.json()["items"] == []


def test_deleted_item_is_returned_as_tombstone(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    first = client.post(
        "/sync/push",
        headers=auth_headers,
        json=_push_body(registered_device),
    )
    first_version = first.json()["accepted"][0]["server_version"]
    deleted_at = 1_784_073_700_000
    deleted = client.post(
        "/sync/push",
        headers=auth_headers,
        json=_push_body(
            registered_device,
            updated_at=deleted_at,
            deleted_at=deleted_at,
            client_version=first_version,
        ),
    )
    assert deleted.status_code == 200

    response = client.post(
        "/sync/pull",
        headers=auth_headers,
        json=_pull_body(registered_device, first_version),
    )

    assert response.status_code == 200
    assert len(response.json()["items"]) == 1
    assert response.json()["items"][0]["deleted_at"] == deleted_at
