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


def _profile_push_body(device_id: str, profile_id: str) -> dict[str, object]:
    return {
        "device_id": device_id,
        "items": [
            {
                "table": "user_profiles",
                "id": profile_id,
                "payload": {
                    "display_name": "Synced profile",
                    "growth_focus": "Deep work",
                    "timezone_id": "Asia/Shanghai",
                    "updated_at": 1_784_073_600_000,
                },
                "updated_at": 1_784_073_600_000,
                "deleted_at": None,
                "origin_device_id": "profile-source-installation",
                "client_version": 0,
            }
        ],
    }


def _profile_pull_body(device_id: str) -> dict[str, object]:
    return {
        "device_id": device_id,
        "since_server_version": 0,
        "tables": ["user_profiles"],
    }


def _register_device(
    client: TestClient,
    headers: dict[str, str],
    installation_id: str,
) -> str:
    response = client.post(
        "/devices/register",
        headers=headers,
        json={
            "local_installation_id": installation_id,
            "platform": "windows",
            "device_name": "Profile sync test device",
            "app_version": "1.0.0+1",
        },
    )
    assert response.status_code == 200
    return response.json()["device_id"]


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


def test_second_device_can_pull_profile_for_the_same_user(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    pushed = client.post(
        "/sync/push",
        headers=auth_headers,
        json=_profile_push_body(registered_device, "windows-profile-id"),
    )
    assert pushed.status_code == 200
    assert pushed.json()["accepted"][0]["id"] == "profile"
    second_device = _register_device(
        client,
        auth_headers,
        "pytest-second-installation",
    )

    pulled = client.post(
        "/sync/pull",
        headers=auth_headers,
        json=_profile_pull_body(second_device),
    )

    assert pulled.status_code == 200
    assert len(pulled.json()["items"]) == 1
    assert pulled.json()["items"][0]["table"] == "user_profiles"
    assert pulled.json()["items"][0]["id"] == "profile"
    assert pulled.json()["items"][0]["payload"]["display_name"] == "Synced profile"


def test_profile_items_are_isolated_between_users(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    pushed = client.post(
        "/sync/push",
        headers=auth_headers,
        json=_profile_push_body(registered_device, "private-profile-id"),
    )
    assert pushed.status_code == 200
    other_login = client.post(
        "/auth/dev-login",
        json={"dev_user_key": "another-profile-user"},
    )
    assert other_login.status_code == 200
    other_headers = {
        "Authorization": f"Bearer {other_login.json()['access_token']}"
    }
    other_device = _register_device(
        client,
        other_headers,
        "pytest-other-user-installation",
    )

    pulled = client.post(
        "/sync/pull",
        headers=other_headers,
        json=_profile_pull_body(other_device),
    )

    assert pulled.status_code == 200
    assert pulled.json()["items"] == []


def test_two_local_profile_ids_map_to_one_canonical_profile(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    first = client.post(
        "/sync/push",
        headers=auth_headers,
        json=_profile_push_body(registered_device, "windows-local-profile"),
    )
    second = client.post(
        "/sync/push",
        headers=auth_headers,
        json=_profile_push_body(registered_device, "android-local-profile"),
    )

    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json()["accepted"][0]["id"] == "profile"
    assert second.json()["accepted"][0]["id"] == "profile"
    pulled = client.post(
        "/sync/pull",
        headers=auth_headers,
        json=_profile_pull_body(registered_device),
    )
    assert [item["id"] for item in pulled.json()["items"]] == ["profile"]
