from __future__ import annotations

import json
import uuid
from concurrent.futures import ThreadPoolExecutor

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select

from app.models import CloudUser, SyncClock, SyncItem
from app.schemas import SyncPullRequest
from app.services import sync_service


def _profile_pull(device_id: str) -> dict[str, object]:
    return {
        "device_id": device_id,
        "since_server_version": 0,
        "tables": ["user_profiles"],
    }


def _today_push(device_id: str, record_id: str) -> dict[str, object]:
    return {
        "device_id": device_id,
        "items": [
            {
                "table": "today_records",
                "id": record_id,
                "payload": {"record_date": "2026-07-16"},
                "updated_at": 1_784_160_000_000,
                "deleted_at": None,
                "origin_device_id": "clock-test-installation",
                "client_version": 0,
            }
        ],
    }


def test_legacy_profiles_migrate_latest_to_canonical_and_remain_preserved(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    database = client.app.state.database
    with database.session_factory() as session:
        user_id = session.scalar(select(CloudUser.id))
        assert user_id is not None
        for record_id, version, name in [
            ("windows-legacy", 4, "Windows old"),
            ("android-legacy", 9, "Android newest"),
        ]:
            session.add(
                SyncItem(
                    id=str(uuid.uuid4()),
                    user_id=user_id,
                    table_name="user_profiles",
                    record_id=record_id,
                    payload_json=json.dumps(
                        {
                            "display_name": name,
                            "growth_focus": "Research",
                            "timezone_id": "Asia/Shanghai",
                            "updated_at": version * 100,
                        }
                    ),
                    server_version=version,
                    client_updated_at=version * 100,
                    server_updated_at=version * 100,
                    deleted_at=None,
                    origin_device_id=f"{record_id}-device",
                )
            )
        session.commit()

    response = client.post(
        "/sync/pull",
        headers=auth_headers,
        json=_profile_pull(registered_device),
    )

    assert response.status_code == 200
    assert len(response.json()["items"]) == 1
    canonical = response.json()["items"][0]
    assert canonical["id"] == "profile"
    assert canonical["payload"]["display_name"] == "Android newest"
    assert canonical["server_version"] == 10
    with database.session_factory() as session:
        rows = session.scalars(
            select(SyncItem).where(SyncItem.table_name == "user_profiles")
        ).all()
        assert len(rows) == 3
        assert sum(row.record_id == "profile" for row in rows) == 1
        assert {row.record_id for row in rows} >= {
            "windows-legacy",
            "android-legacy",
        }

    repeated = client.post(
        "/sync/pull",
        headers=auth_headers,
        json=_profile_pull(registered_device),
    )
    assert [item["id"] for item in repeated.json()["items"]] == ["profile"]


def test_sync_clock_versions_are_global_across_users(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
) -> None:
    first = client.post(
        "/sync/push",
        headers=auth_headers,
        json=_today_push(registered_device, "first-user-record"),
    )
    other_login = client.post(
        "/auth/dev-login", json={"dev_user_key": "clock-other-user"}
    )
    other_headers = {
        "Authorization": f"Bearer {other_login.json()['access_token']}"
    }
    registration = client.post(
        "/devices/register",
        headers=other_headers,
        json={
            "local_installation_id": "clock-other-installation",
            "platform": "android",
            "device_name": "Clock Android",
            "app_version": "1.0.0+1",
        },
    )
    second = client.post(
        "/sync/push",
        headers=other_headers,
        json=_today_push(registration.json()["device_id"], "second-user-record"),
    )

    first_version = first.json()["accepted"][0]["server_version"]
    second_version = second.json()["accepted"][0]["server_version"]
    assert second_version > first_version
    assert second_version != first_version
    with client.app.state.database.session_factory() as session:
        assert session.scalar(select(SyncClock.current_version)) == second_version


def test_concurrent_legacy_migration_keeps_one_committed_canonical_cursor(
    client: TestClient,
    registered_device: str,
) -> None:
    database = client.app.state.database
    with database.session_factory() as session:
        user_id = session.scalar(select(CloudUser.id))
        assert user_id is not None
        session.add(
            SyncItem(
                id=str(uuid.uuid4()),
                user_id=user_id,
                table_name="user_profiles",
                record_id="legacy-concurrent-profile",
                payload_json=json.dumps(
                    {
                        "display_name": "Concurrent legacy",
                        "growth_focus": "Reliability",
                        "timezone_id": "Etc/UTC",
                        "updated_at": 500,
                    }
                ),
                server_version=5,
                client_updated_at=500,
                server_updated_at=500,
                deleted_at=None,
                origin_device_id="legacy-concurrent-device",
            )
        )
        session.commit()

    body = SyncPullRequest(
        device_id=registered_device,
        since_server_version=0,
        tables=["user_profiles"],
    )

    def migrate() -> int:
        with database.session_factory() as session:
            return sync_service.pull(session, user_id, body).server_version

    with ThreadPoolExecutor(max_workers=2) as executor:
        returned_versions = list(executor.map(lambda _: migrate(), range(2)))

    with database.session_factory() as session:
        canonical_count = session.scalar(
            select(func.count(SyncItem.id)).where(
                SyncItem.user_id == user_id,
                SyncItem.table_name == "user_profiles",
                SyncItem.record_id == "profile",
            )
        )
        committed_version = session.scalar(select(SyncClock.current_version))
    assert canonical_count == 1
    assert committed_version == 6
    assert returned_versions == [6, 6]


def test_failed_transaction_rolls_back_clock_increment(
    client: TestClient,
    auth_headers: dict[str, str],
    registered_device: str,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    original = sync_service._next_server_version

    def fail_after_allocation(session: object) -> int:
        original(session)
        raise RuntimeError("simulated write failure")

    monkeypatch.setattr(sync_service, "_next_server_version", fail_after_allocation)
    with pytest.raises(RuntimeError, match="simulated write failure"):
        client.post(
            "/sync/push",
            headers=auth_headers,
            json=_today_push(registered_device, "failed-record"),
        )
    monkeypatch.setattr(sync_service, "_next_server_version", original)

    successful = client.post(
        "/sync/push",
        headers=auth_headers,
        json=_today_push(registered_device, "successful-record"),
    )
    assert successful.json()["accepted"][0]["server_version"] == 1
    with client.app.state.database.session_factory() as session:
        assert session.scalar(select(func.count(SyncItem.id))) == 1
