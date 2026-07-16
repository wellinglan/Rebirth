from fastapi.testclient import TestClient


def test_health_returns_ok(client: TestClient) -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "service": "rebirth-api",
        "api_version": 1,
        "sync_protocol_version": 2,
        "environment": "development",
    }
