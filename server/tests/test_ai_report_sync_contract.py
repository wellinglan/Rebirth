from __future__ import annotations

from fastapi.testclient import TestClient


REPORT_ID = "71111111-1111-4111-8111-111111111111"
VERSION_ID = "72222222-2222-4222-8222-222222222222"
ORIGIN_ID = "73333333-3333-4333-8333-333333333333"


def _payload(
    *,
    content: str = "A private report",
    version_id: str = VERSION_ID,
    status: str = "completed",
):
    return {
        "report_type": "weekly_report",
        "title": "Weekly review",
        "period_start_date": "2026-08-01",
        "period_end_date": "2026-08-07",
        "report_status": status,
        "created_at": 1_786_000_000_000,
        "generation_source": "ai_coach",
        "sensitivity": "high",
        "quality": "unreviewed",
        "current_version": 1,
        "versions": [{
            "id": version_id,
            "version": 1,
            "status": "completed",
            "generation_source": "ai_coach",
            "content": content,
            "sensitivity": "high",
            "quality": "unreviewed",
            "error_code": None,
            "created_at": 1_786_000_000_000,
            "completed_at": 1_786_000_000_100,
        }],
    }


def _push(client: TestClient, headers: dict[str, str], device_id: str, *, payload=None, client_version=0, deleted_at=None):
    return client.post("/sync/push", headers=headers, json={"device_id": device_id, "items": [{
        "table": "ai_reports", "id": REPORT_ID, "payload": {} if deleted_at is not None else (payload or _payload()),
        "updated_at": 1_786_000_000_200, "deleted_at": deleted_at,
        "origin_device_id": ORIGIN_ID, "client_version": client_version,
    }]})


def test_ai_report_push_pull_and_tombstone_use_existing_protocol_v2(
    client: TestClient, auth_headers: dict[str, str], registered_device: str
) -> None:
    created = _push(client, auth_headers, registered_device)
    assert created.status_code == 200
    version = created.json()["accepted"][0]["server_version"]
    pulled = client.post("/sync/pull", headers=auth_headers, json={
        "device_id": registered_device, "since_server_version": 0, "tables": ["ai_reports"]
    })
    assert pulled.status_code == 200
    assert pulled.json()["items"][0]["payload"] == _payload()
    deleted = _push(client, auth_headers, registered_device, client_version=version, deleted_at=1_786_000_000_300)
    assert deleted.status_code == 200


def test_ai_report_rejects_unsafe_fields_and_version_rewrite(
    client: TestClient, auth_headers: dict[str, str], registered_device: str
) -> None:
    created = _push(client, auth_headers, registered_device)
    version = created.json()["accepted"][0]["server_version"]
    unsafe = _payload()
    unsafe["prompt"] = "must not be synced"
    assert _push(client, auth_headers, registered_device, payload=unsafe).status_code == 422
    rewritten = _payload(content="rewritten")
    response = _push(client, auth_headers, registered_device, payload=rewritten, client_version=version)
    assert response.status_code == 422


def test_ai_report_archive_uses_occ_and_keeps_version_payload(
    client: TestClient, auth_headers: dict[str, str], registered_device: str
) -> None:
    created = _push(client, auth_headers, registered_device)
    first_version = created.json()["accepted"][0]["server_version"]

    archived_payload = _payload(status="archived")
    archived = _push(
        client,
        auth_headers,
        registered_device,
        payload=archived_payload,
        client_version=first_version,
    )
    assert archived.status_code == 200
    archived_version = archived.json()["accepted"][0]["server_version"]
    assert archived_version > first_version

    stale = _push(
        client,
        auth_headers,
        registered_device,
        client_version=first_version,
    )
    assert stale.status_code == 200
    assert stale.json()["accepted"] == []
    assert stale.json()["conflicts"][0]["reason"] == "stale_client"
    assert stale.json()["conflicts"][0]["server_version"] == archived_version

    pulled = client.post(
        "/sync/pull",
        headers=auth_headers,
        json={
            "device_id": registered_device,
            "since_server_version": first_version,
            "tables": ["ai_reports"],
        },
    )
    assert pulled.status_code == 200
    assert pulled.json()["items"][0]["payload"] == archived_payload
