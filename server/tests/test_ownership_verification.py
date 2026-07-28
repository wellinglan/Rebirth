import hashlib
import json

from fastapi.testclient import TestClient


def _login(client: TestClient, key: str) -> dict[str, str]:
    response = client.post("/auth/dev-login", json={"dev_user_key": key})
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def _register(
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
            "device_name": "Ownership test device",
            "app_version": "1.0.0+1",
        },
    )
    assert response.status_code == 200
    return response.json()["device_id"]


def _push_profile(
    client: TestClient,
    headers: dict[str, str],
    device_id: str,
    origin_device_id: str,
    *,
    client_version: int = 0,
    updated_at: int = 100,
) -> dict[str, object]:
    response = client.post(
        "/sync/push",
        headers=headers,
        json={
            "device_id": device_id,
            "items": [
                {
                    "table": "user_profiles",
                    "id": "profile",
                    "payload": {
                        "display_name": "Private profile",
                        "growth_focus": "Private focus",
                        "timezone_id": "Asia/Shanghai",
                        "updated_at": updated_at,
                    },
                    "updated_at": updated_at,
                    "deleted_at": None,
                    "origin_device_id": origin_device_id,
                    "client_version": client_version,
                }
            ],
        },
    )
    assert response.status_code == 200, response.text
    version = response.json()["accepted"][0]["server_version"]
    return {
        "table": "user_profiles",
        "id": "profile",
        "server_version": version,
        "metadata_fingerprint": _fingerprint(
            table="user_profiles",
            record_id="profile",
            server_version=version,
            updated_at=updated_at,
            deleted_at=None,
            origin_device_id=origin_device_id,
        ),
    }


def _push_goal(
    client: TestClient,
    headers: dict[str, str],
    device_id: str,
    origin_device_id: str,
    *,
    goal_id: str,
    client_version: int = 0,
    updated_at: int = 100,
) -> dict[str, object]:
    response = client.post(
        "/sync/push",
        headers=headers,
        json={
            "device_id": device_id,
            "items": [
                {
                    "table": "goals",
                    "id": goal_id,
                    "payload": {
                        "parent_goal_id": None,
                        "title": "Private goal",
                        "description": None,
                        "goal_level": "month",
                        "status": "not_started",
                        "start_date": "2026-07-01",
                        "target_date": "2026-07-31",
                        "completed_at": None,
                        "archived_at": None,
                        "sort_order": 0,
                        "created_at": 90,
                    },
                    "updated_at": updated_at,
                    "deleted_at": None,
                    "origin_device_id": origin_device_id,
                    "client_version": client_version,
                }
            ],
        },
    )
    assert response.status_code == 200, response.text
    version = response.json()["accepted"][0]["server_version"]
    return {
        "table": "goals",
        "id": goal_id,
        "server_version": version,
        "metadata_fingerprint": _fingerprint(
            table="goals",
            record_id=goal_id,
            server_version=version,
            updated_at=updated_at,
            deleted_at=None,
            origin_device_id=origin_device_id,
        ),
    }


def _fingerprint(
    *,
    table: str,
    record_id: str,
    server_version: int,
    updated_at: int,
    deleted_at: int | None,
    origin_device_id: str,
) -> str:
    canonical = json.dumps(
        {
            "deleted_at": deleted_at,
            "origin_device_id": origin_device_id,
            "record_id": record_id,
            "server_version": server_version,
            "table": table,
            "updated_at": updated_at,
        },
        ensure_ascii=True,
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def test_verification_requires_access_token(client: TestClient) -> None:
    response = client.post("/sync/verify-ownership", json={"evidence": []})

    assert response.status_code == 401


def test_matching_current_user_metadata_is_verified(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    evidence = _push_profile(
        client,
        auth_headers,
        registered_device,
        "pytest-installation",
    )

    response = client.post(
        "/sync/verify-ownership",
        headers=auth_headers,
        json={"evidence": [evidence]},
    )

    assert response.status_code == 200
    assert response.json() == {
        "status": "verified",
        "verified_count": 1,
        "rejected_count": 0,
        "unknown_count": 0,
        "reason": "all_evidence_matches_current_user",
    }


def test_unknown_record_keeps_ownership_unverified(
    client: TestClient,
    auth_headers: dict[str, str],
) -> None:
    response = client.post(
        "/sync/verify-ownership",
        headers=auth_headers,
        json={
            "evidence": [
                {
                    "table": "goals",
                    "id": "10000000-0000-4000-8000-000000000001",
                    "server_version": 99,
                    "metadata_fingerprint": "a" * 64,
                }
            ]
        },
    )

    assert response.status_code == 200
    assert response.json()["status"] == "unknown"
    assert response.json()["reason"] == "remote_record_missing"


def test_stale_goal_metadata_for_current_user_is_verified(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    goal_id = "10000000-0000-4000-8000-000000000002"
    stale_evidence = _push_goal(
        client,
        auth_headers,
        registered_device,
        registered_device,
        goal_id=goal_id,
    )
    _push_goal(
        client,
        auth_headers,
        registered_device,
        registered_device,
        goal_id=goal_id,
        client_version=int(stale_evidence["server_version"]),
        updated_at=200,
    )

    response = client.post(
        "/sync/verify-ownership",
        headers=auth_headers,
        json={"evidence": [stale_evidence]},
    )

    assert response.status_code == 200
    assert response.json()["status"] == "verified"
    assert response.json()["verified_count"] == 1


def test_stale_goal_owned_by_other_user_is_rejected(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    goal_id = "10000000-0000-4000-8000-000000000003"
    stale_evidence = _push_goal(
        client,
        auth_headers,
        registered_device,
        registered_device,
        goal_id=goal_id,
    )
    _push_goal(
        client,
        auth_headers,
        registered_device,
        registered_device,
        goal_id=goal_id,
        client_version=int(stale_evidence["server_version"]),
        updated_at=200,
    )
    other_headers = _login(client, "ownership-stale-other-user")

    response = client.post(
        "/sync/verify-ownership",
        headers=other_headers,
        json={"evidence": [stale_evidence]},
    )

    assert response.status_code == 200
    assert response.json()["status"] == "rejected"


def test_stale_profile_only_evidence_is_unknown(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    stale_evidence = _push_profile(
        client,
        auth_headers,
        registered_device,
        "pytest-installation",
    )
    _push_profile(
        client,
        auth_headers,
        registered_device,
        "pytest-installation",
        client_version=int(stale_evidence["server_version"]),
        updated_at=200,
    )

    response = client.post(
        "/sync/verify-ownership",
        headers=auth_headers,
        json={"evidence": [stale_evidence]},
    )

    assert response.status_code == 200
    assert response.json()["status"] == "unknown"
    assert response.json()["reason"] == "remote_record_missing"


def test_wrong_user_is_rejected_without_returning_private_content(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    evidence = _push_profile(
        client,
        auth_headers,
        registered_device,
        "pytest-installation",
    )
    other_headers = _login(client, "ownership-other-user")

    response = client.post(
        "/sync/verify-ownership",
        headers=other_headers,
        json={"evidence": [evidence]},
    )

    assert response.status_code == 200
    assert response.json()["status"] == "rejected"
    assert "Private profile" not in response.text
    assert "pytest-user" not in response.text


def test_metadata_forgery_is_rejected(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    evidence = _push_profile(
        client,
        auth_headers,
        registered_device,
        "pytest-installation",
    )
    evidence["metadata_fingerprint"] = "b" * 64

    response = client.post(
        "/sync/verify-ownership",
        headers=auth_headers,
        json={
            "evidence": [evidence],
            "user_id": "forged-user",
            "ownership": "verified",
        },
    )

    assert response.status_code == 422


def test_duplicate_evidence_is_rejected_as_invalid_request(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    evidence = _push_profile(
        client,
        auth_headers,
        registered_device,
        "pytest-installation",
    )

    response = client.post(
        "/sync/verify-ownership",
        headers=auth_headers,
        json={"evidence": [evidence, evidence]},
    )

    assert response.status_code == 422
