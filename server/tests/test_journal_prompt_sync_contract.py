from __future__ import annotations

from copy import deepcopy

from fastapi.testclient import TestClient


CONFIG_ID = "51111111-1111-4111-8111-111111111111"
SECOND_CONFIG_ID = "52222222-2222-4222-8222-222222222222"
PROMPT_ID = "53333333-3333-4333-8333-333333333333"
ITEM_ID = "54444444-4444-4444-8444-444444444444"
JOURNAL_ID = "55555555-5555-4555-8555-555555555555"
ORIGIN_ID = "56666666-6666-4666-8666-666666666666"


def _prompt_payload() -> dict[str, object]:
    return {
        "payload_schema_version": 1,
        "logical_key": "default",
        "configuration_version": 1,
        "created_at": 100,
        "prompts": [
            {
                "id": PROMPT_ID,
                "stable_key": "system.accomplishment",
                "source": "system",
                "question_text": "What mattered today?",
                "helper_text": None,
                "response_kind": "long_text",
                "display_order": 0,
                "is_enabled": True,
                "prompt_version": 1,
                "created_at": 100,
                "updated_at": 100,
                "deleted_at": None,
            }
        ],
    }


def _journal_v2_payload() -> dict[str, object]:
    return {
        "journal_payload_schema_version": 2,
        "entry_date": "2026-07-29",
        "timezone_offset_minutes": 480,
        "entry_status": "draft",
        "created_at": 100,
        "prompt_items": [
            {
                "id": ITEM_ID,
                "source_prompt_id": PROMPT_ID,
                "source_prompt_stable_key": "system.accomplishment",
                "source_prompt_version": 1,
                "prompt_source": "system",
                "question_text_snapshot": "What mattered today?",
                "helper_text_snapshot": None,
                "response_kind": "long_text",
                "display_order": 0,
                "answer_text": "A private answer",
                "created_at": 100,
                "updated_at": 100,
            }
        ],
    }


def _item(
    table: str,
    record_id: str,
    payload: dict[str, object],
) -> dict[str, object]:
    return {
        "table": table,
        "id": record_id,
        "payload": payload,
        "updated_at": 200,
        "deleted_at": None,
        "origin_device_id": ORIGIN_ID,
        "client_version": 0,
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


def test_journal_v2_is_typed_and_preserved_on_pull(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    payload = _journal_v2_payload()
    response = _push(
        client,
        auth_headers,
        registered_device,
        _item("journal_entries", JOURNAL_ID, payload),
    )
    assert response.status_code == 200

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
    assert pulled.json()["items"][0]["payload"] == payload


def test_journal_v2_rejects_duplicate_items_and_empty_answers(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    duplicate = _journal_v2_payload()
    duplicate["prompt_items"] = [
        duplicate["prompt_items"][0],
        deepcopy(duplicate["prompt_items"][0]),
    ]
    empty = _journal_v2_payload()
    empty["prompt_items"][0]["answer_text"] = None

    assert _push(
        client,
        auth_headers,
        registered_device,
        _item("journal_entries", JOURNAL_ID, duplicate),
    ).status_code == 422
    assert _push(
        client,
        auth_headers,
        registered_device,
        _item(
            "journal_entries",
            "57777777-7777-4777-8777-777777777777",
            empty,
        ),
    ).status_code == 422


def test_prompt_configuration_is_typed_and_preserved_on_pull(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    payload = _prompt_payload()
    created = _push(
        client,
        auth_headers,
        registered_device,
        _item("journal_prompt_configurations", CONFIG_ID, payload),
    )
    assert created.status_code == 200

    pulled = client.post(
        "/sync/pull",
        headers=auth_headers,
        json={
            "device_id": registered_device,
            "since_server_version": 0,
            "tables": ["journal_prompt_configurations"],
        },
    )
    assert pulled.status_code == 200
    assert pulled.json()["items"][0]["payload"] == payload


def test_prompt_configuration_rejects_invalid_child_contract(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    invalid = _prompt_payload()
    invalid["prompts"][0]["stable_key"] = None

    response = _push(
        client,
        auth_headers,
        registered_device,
        _item("journal_prompt_configurations", CONFIG_ID, invalid),
    )
    assert response.status_code == 422


def test_prompt_configuration_logical_key_conflict_is_structured(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    first = _push(
        client,
        auth_headers,
        registered_device,
        _item(
            "journal_prompt_configurations",
            CONFIG_ID,
            _prompt_payload(),
        ),
    )
    different = _prompt_payload()
    different["prompts"][0]["question_text"] = "A different question"
    second = _push(
        client,
        auth_headers,
        registered_device,
        _item(
            "journal_prompt_configurations",
            SECOND_CONFIG_ID,
            different,
        ),
    )

    assert first.status_code == 200
    assert second.status_code == 200
    conflict = second.json()["conflicts"][0]
    assert conflict["id"] == SECOND_CONFIG_ID
    assert conflict["remote_record_id"] == CONFIG_ID
    assert conflict["reason"] == "journal_prompt_logical_key_conflict"


def test_duplicate_logical_keys_in_one_batch_return_a_structured_conflict(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    first_id = "58888888-8888-4888-8888-888888888888"
    second_id = "59999999-9999-4999-8999-999999999999"
    first = _item(
        "journal_prompt_configurations",
        first_id,
        _prompt_payload(),
    )
    different = _prompt_payload()
    different["prompts"][0]["question_text"] = "A batched difference"
    second = _item(
        "journal_prompt_configurations",
        second_id,
        different,
    )

    response = client.post(
        "/sync/push",
        headers=auth_headers,
        json={"device_id": registered_device, "items": [first, second]},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["accepted"] == []
    conflicts = {item["id"]: item for item in body["conflicts"]}
    assert conflicts[first_id]["reason"] == "request_conflict"
    assert conflicts[second_id]["remote_record_id"] == first_id
    assert conflicts[second_id]["server_version"] == 0
