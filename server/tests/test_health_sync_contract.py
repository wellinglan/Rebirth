from __future__ import annotations

from fastapi.testclient import TestClient


HEALTH_ID = "41111111-1111-4111-8111-111111111111"
SECOND_HEALTH_ID = "42222222-2222-4222-8222-222222222222"
ORIGIN_ID = "43333333-3333-4333-8333-333333333333"


def _payload(
    *,
    record_date: str = "2026-07-28",
    note: str | None = "Private Health note",
) -> dict[str, object]:
    return {
        "record_date": record_date,
        "timezone_offset_minutes": 480,
        "sleep_duration_minutes": 450,
        "weight_kg": 65.5,
        "water_intake_ml": 1500,
        "exercise_type": "run",
        "exercise_duration_minutes": 30,
        "physical_state_score": 4,
        "note": note,
        "data_source": "manual",
        "source_record_id": None,
        "created_at": 1_785_196_000_000,
    }


def _current_payload(
    *,
    score_scale: int = 10,
    physical_state_score: int = 9,
) -> dict[str, object]:
    payload = _payload()
    payload.update(
        {
            "physical_state_score": physical_state_score,
            "physical_state_score_scale": score_scale,
            "physical_state_description": "Recovered after exercise",
        }
    )
    return payload


def _narrative_payload() -> dict[str, object]:
    payload = _current_payload()
    payload.update(
        {
            "sleep_description": "Rested well",
            "weight_description": None,
            "water_description": "Drank steadily",
            "exercise_description": "Easy recovery run",
        }
    )
    return payload


def _item(
    *,
    record_id: str = HEALTH_ID,
    payload: dict[str, object] | None = None,
    client_version: int = 0,
    updated_at: int = 1_785_196_800_000,
    deleted_at: int | None = None,
) -> dict[str, object]:
    return {
        "table": "health_records",
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


def test_health_create_retry_and_pull_are_typed_and_idempotent(
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
            "tables": ["health_records"],
        },
    )
    assert pulled.status_code == 200
    assert pulled.json()["items"][0]["payload"] == _payload()


def test_health_current_physical_state_payload_round_trips_without_field_loss(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    payload = _current_payload()

    pushed = _push(
        client,
        auth_headers,
        registered_device,
        _item(payload=payload),
    )
    pulled = client.post(
        "/sync/pull",
        headers=auth_headers,
        json={
            "device_id": registered_device,
            "since_server_version": 0,
            "tables": ["health_records"],
        },
    )

    assert pushed.status_code == 200
    assert pulled.status_code == 200
    assert pulled.json()["items"][0]["payload"] == payload


def test_health_narrative_payload_round_trips_null_and_text_without_field_loss(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    payload = _narrative_payload()

    pushed = _push(
        client,
        auth_headers,
        registered_device,
        _item(payload=payload),
    )
    pulled = client.post(
        "/sync/pull",
        headers=auth_headers,
        json={
            "device_id": registered_device,
            "since_server_version": 0,
            "tables": ["health_records"],
        },
    )

    assert pushed.status_code == 200
    assert pulled.status_code == 200
    assert pulled.json()["items"][0]["payload"] == payload


def test_health_current_scale_five_payload_remains_supported(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    payload = _current_payload(score_scale=5, physical_state_score=5)

    response = _push(
        client,
        auth_headers,
        registered_device,
        _item(payload=payload),
    )

    assert response.status_code == 200


def test_health_rejects_invalid_payload(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    invalid_score = _payload()
    invalid_score["physical_state_score"] = 6
    extra_field = _payload()
    extra_field["today_record_id"] = "must-not-cross-wire"

    score_response = _push(
        client,
        auth_headers,
        registered_device,
        _item(payload=invalid_score),
    )
    extra_response = _push(
        client,
        auth_headers,
        registered_device,
        _item(record_id=SECOND_HEALTH_ID, payload=extra_field),
    )

    assert score_response.status_code == 422
    assert extra_response.status_code == 422


def test_health_rejects_partial_or_inconsistent_physical_state_extensions(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    partial = _payload()
    partial["physical_state_score_scale"] = 10
    mismatched = _current_payload(score_scale=5, physical_state_score=6)
    overlong = _current_payload()
    overlong["physical_state_description"] = "x" * 81

    responses = [
        _push(
            client,
            auth_headers,
            registered_device,
            _item(payload=payload),
        )
        for payload in (partial, mismatched, overlong)
    ]

    assert all(response.status_code == 422 for response in responses)


def test_health_rejects_partial_or_detached_narrative_extensions(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    partial = _current_payload()
    partial["sleep_description"] = "Only one new key"
    detached = _payload()
    detached.update(
        {
            "sleep_description": "Missing physical-state generation",
            "weight_description": None,
            "water_description": None,
            "exercise_description": None,
        }
    )
    overlong = _narrative_payload()
    overlong["water_description"] = "x" * 81

    responses = [
        _push(
            client,
            auth_headers,
            registered_device,
            _item(payload=payload),
        )
        for payload in (partial, detached, overlong)
    ]

    assert all(response.status_code == 422 for response in responses)


def test_health_tombstone_requires_an_empty_payload(
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


def test_health_returns_structured_conflict_for_second_identity_on_same_date(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    first = _push(client, auth_headers, registered_device, _item())
    second = _push(
        client,
        auth_headers,
        registered_device,
        _item(record_id=SECOND_HEALTH_ID),
    )

    assert first.status_code == 200
    assert second.status_code == 200
    assert second.json()["accepted"] == []
    assert second.json()["conflicts"] == [
        {
            "table": "health_records",
            "id": SECOND_HEALTH_ID,
            "server_version": first.json()["accepted"][0]["server_version"],
            "reason": "health_record_date_conflict",
            "remote_record_id": HEALTH_ID,
        }
    ]


def test_health_same_date_batch_conflict_is_atomic(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    response = client.post(
        "/sync/push",
        headers=auth_headers,
        json={
            "device_id": registered_device,
            "items": [
                _item(record_id=HEALTH_ID),
                _item(record_id=SECOND_HEALTH_ID),
            ],
        },
    )

    assert response.status_code == 200
    assert response.json()["accepted"] == []
    assert {item["reason"] for item in response.json()["conflicts"]} == {
        "request_conflict",
        "health_record_date_conflict",
    }
    pulled = client.post(
        "/sync/pull",
        headers=auth_headers,
        json={
            "device_id": registered_device,
            "since_server_version": 0,
            "tables": ["health_records"],
        },
    )
    assert pulled.status_code == 200
    assert pulled.json()["items"] == []


def test_health_record_date_is_immutable_and_stale_occ_conflicts(
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
    stale = _push(
        client,
        auth_headers,
        registered_device,
        _item(
            payload=_payload(note="Stale local edit"),
            client_version=0,
            updated_at=1_785_283_300_000,
        ),
    )

    assert changed.status_code == 422
    assert stale.status_code == 200
    assert stale.json()["accepted"] == []
    assert stale.json()["conflicts"][0]["server_version"] == version


def test_health_pull_is_isolated_by_jwt_user(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    assert (
        _push(
            client,
            auth_headers,
            registered_device,
            _item(payload=_narrative_payload()),
        ).status_code
        == 200
    )
    login = client.post(
        "/auth/dev-login",
        json={"dev_user_key": "health-other-user"},
    )
    other_headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
    registration = client.post(
        "/devices/register",
        headers=other_headers,
        json={
            "local_installation_id": "health-other-installation",
            "platform": "android",
            "device_name": "Other Health device",
            "app_version": "1.0.0+1",
        },
    )
    pulled = client.post(
        "/sync/pull",
        headers=other_headers,
        json={
            "device_id": registration.json()["device_id"],
            "since_server_version": 0,
            "tables": ["health_records"],
        },
    )

    assert pulled.status_code == 200
    assert pulled.json()["items"] == []
