from fastapi.testclient import TestClient


def test_dev_login_returns_access_token(client: TestClient) -> None:
    response = client.post(
        "/auth/dev-login",
        json={"dev_user_key": "local-test-user"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["access_token"]
    assert body["refresh_token"]
    assert body["token_type"] == "bearer"


def test_dev_login_returns_same_user_for_same_key(client: TestClient) -> None:
    first = client.post(
        "/auth/dev-login",
        json={"dev_user_key": "stable-user"},
    )
    second = client.post(
        "/auth/dev-login",
        json={"dev_user_key": "stable-user"},
    )

    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json()["user"]["id"] == second.json()["user"]["id"]


def test_wechat_mobile_is_explicitly_not_implemented(client: TestClient) -> None:
    response = client.post(
        "/auth/wechat/mobile",
        json={"code": "not-a-real-provider-code", "platform": "android"},
    )

    assert response.status_code == 200
    assert response.json()["status"] == "not_implemented"
    assert "Open Platform" in response.json()["message"]
