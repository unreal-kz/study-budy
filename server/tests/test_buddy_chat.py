from unittest.mock import AsyncMock

from fastapi.testclient import TestClient

from app.main import app
from app.openrouter_client import OpenRouterError, RateLimitedError

client = TestClient(app)


def test_buddy_chat_returns_reply(monkeypatch):
    async def fake_get_buddy_reply(history, message, level):
        return {"reply": "Great!", "correction": None, "explanation": None}

    monkeypatch.setattr("app.main.get_buddy_reply", fake_get_buddy_reply)

    response = client.post(
        "/buddy/chat",
        json={"history": [], "message": "I go to school yesterday.", "level": "A2"},
    )
    assert response.status_code == 200
    assert response.json() == {
        "reply": "Great!",
        "correction": None,
        "explanation": None,
    }


def test_buddy_chat_rate_limited_returns_429(monkeypatch):
    async def raise_rate_limited(history, message, level):
        raise RateLimitedError("nope")

    monkeypatch.setattr("app.main.get_buddy_reply", raise_rate_limited)

    response = client.post(
        "/buddy/chat", json={"history": [], "message": "Hi", "level": "B1"}
    )
    assert response.status_code == 429
    assert "tomorrow" in response.json()["detail"]


def test_buddy_chat_upstream_error_returns_502(monkeypatch):
    async def raise_openrouter_error(history, message, level):
        raise OpenRouterError("boom")

    monkeypatch.setattr("app.main.get_buddy_reply", raise_openrouter_error)

    response = client.post(
        "/buddy/chat", json={"history": [], "message": "Hi", "level": "B1"}
    )
    assert response.status_code == 502


def test_buddy_chat_no_app_token_configured_allows_request(monkeypatch):
    monkeypatch.delenv("APP_TOKEN", raising=False)

    async def fake_get_buddy_reply(history, message, level):
        return {"reply": "ok", "correction": None, "explanation": None}

    monkeypatch.setattr("app.main.get_buddy_reply", fake_get_buddy_reply)

    response = client.post(
        "/buddy/chat", json={"history": [], "message": "Hi", "level": "B1"}
    )
    assert response.status_code == 200


def test_buddy_chat_rejects_missing_token_when_configured(monkeypatch):
    monkeypatch.setenv("APP_TOKEN", "secret-token")

    response = client.post(
        "/buddy/chat", json={"history": [], "message": "Hi", "level": "B1"}
    )
    assert response.status_code == 401


def test_buddy_chat_rejects_wrong_token_when_configured(monkeypatch):
    monkeypatch.setenv("APP_TOKEN", "secret-token")

    response = client.post(
        "/buddy/chat",
        json={"history": [], "message": "Hi", "level": "B1"},
        headers={"X-App-Token": "wrong-token"},
    )
    assert response.status_code == 401


def test_buddy_chat_accepts_matching_token_when_configured(monkeypatch):
    monkeypatch.setenv("APP_TOKEN", "secret-token")

    async def fake_get_buddy_reply(history, message, level):
        return {"reply": "ok", "correction": None, "explanation": None}

    monkeypatch.setattr("app.main.get_buddy_reply", fake_get_buddy_reply)

    response = client.post(
        "/buddy/chat",
        json={"history": [], "message": "Hi", "level": "B1"},
        headers={"X-App-Token": "secret-token"},
    )
    assert response.status_code == 200
