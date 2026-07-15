from fastapi.testclient import TestClient


_DEVICE_BODY = {
    "local_installation_id": "device-test-installation",
    "platform": "windows",
    "device_name": "Device Test PC",
    "app_version": "1.0.0+1",
}


def test_device_registration_requires_access_token(client: TestClient) -> None:
    response = client.post("/devices/register", json=_DEVICE_BODY)

    assert response.status_code == 401


def test_authenticated_user_can_register_device(
    client: TestClient,
    auth_headers: dict[str, str],
) -> None:
    response = client.post(
        "/devices/register",
        headers=auth_headers,
        json=_DEVICE_BODY,
    )

    assert response.status_code == 200
    assert response.json()["device_id"]
    assert isinstance(response.json()["server_time"], int)


def test_device_registration_is_idempotent(
    client: TestClient,
    auth_headers: dict[str, str],
) -> None:
    first = client.post(
        "/devices/register",
        headers=auth_headers,
        json=_DEVICE_BODY,
    )
    second = client.post(
        "/devices/register",
        headers=auth_headers,
        json={**_DEVICE_BODY, "device_name": "Renamed PC"},
    )

    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json()["device_id"] == second.json()["device_id"]
