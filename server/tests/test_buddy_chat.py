from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.openrouter_client import OpenRouterError, RateLimitedError

client = TestClient(app)


def test_buddy_chat_returns_reply(monkeypatch):
    async def fake_get_buddy_reply(history, message, level, **kwargs):
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
    async def raise_rate_limited(history, message, level, **kwargs):
        raise RateLimitedError("nope")

    monkeypatch.setattr("app.main.get_buddy_reply", raise_rate_limited)

    response = client.post(
        "/buddy/chat", json={"history": [], "message": "Hi", "level": "B1"}
    )
    assert response.status_code == 429
    assert "tomorrow" in response.json()["detail"]


def test_buddy_chat_upstream_error_returns_502(monkeypatch):
    async def raise_openrouter_error(history, message, level, **kwargs):
        raise OpenRouterError("boom")

    monkeypatch.setattr("app.main.get_buddy_reply", raise_openrouter_error)

    response = client.post(
        "/buddy/chat", json={"history": [], "message": "Hi", "level": "B1"}
    )
    assert response.status_code == 502


def test_buddy_chat_no_app_token_configured_allows_request(monkeypatch):
    monkeypatch.delenv("APP_TOKEN", raising=False)

    async def fake_get_buddy_reply(history, message, level, **kwargs):
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

    async def fake_get_buddy_reply(history, message, level, **kwargs):
        return {"reply": "ok", "correction": None, "explanation": None}

    monkeypatch.setattr("app.main.get_buddy_reply", fake_get_buddy_reply)

    response = client.post(
        "/buddy/chat",
        json={"history": [], "message": "Hi", "level": "B1"},
        headers={"X-App-Token": "secret-token"},
    )
    assert response.status_code == 200


# ---- ST-54: optional mode / topic -------------------------------------------


def _capture_calls(monkeypatch):
    """Replaces get_buddy_reply with a recorder; returns the list of its kwargs."""
    calls = []

    async def fake_get_buddy_reply(history, message, level, **kwargs):
        calls.append({"history": history, "message": message, "level": level, **kwargs})
        return {"reply": "ok", "correction": None, "explanation": None}

    monkeypatch.setattr("app.main.get_buddy_reply", fake_get_buddy_reply)
    return calls


def test_buddy_chat_without_mode_or_topic_passes_none(monkeypatch):
    # Exactly the body the prod client on main sends.
    calls = _capture_calls(monkeypatch)

    response = client.post(
        "/buddy/chat",
        json={"history": [], "message": "I go to school yesterday.", "level": "A2"},
    )

    assert response.status_code == 200
    assert calls == [
        {
            "history": [],
            "message": "I go to school yesterday.",
            "level": "A2",
            "mode": None,
            "topic": None,
        }
    ]


def test_buddy_chat_forwards_mode_and_topic(monkeypatch):
    calls = _capture_calls(monkeypatch)

    response = client.post(
        "/buddy/chat",
        json={
            "history": [{"role": "assistant", "content": "Hello!"}],
            "message": "I like films",
            "level": "B1",
            "mode": "topic",
            "topic": "Movies & Music: Favourite film?",
        },
    )

    assert response.status_code == 200
    assert calls[0]["mode"] == "topic"
    assert calls[0]["topic"] == "Movies & Music: Favourite film?"
    assert calls[0]["history"] == [{"role": "assistant", "content": "Hello!"}]


@pytest.mark.parametrize("mode", ["free", "topic", "ielts"])
def test_buddy_chat_accepts_every_known_mode(monkeypatch, mode):
    calls = _capture_calls(monkeypatch)

    response = client.post(
        "/buddy/chat",
        json={"history": [], "message": "Hi", "level": "B1", "mode": mode},
    )

    assert response.status_code == 200
    assert calls[0]["mode"] == mode


def test_buddy_chat_accepts_explicit_nulls(monkeypatch):
    calls = _capture_calls(monkeypatch)

    response = client.post(
        "/buddy/chat",
        json={"history": [], "message": "Hi", "level": "B1", "mode": None, "topic": None},
    )

    assert response.status_code == 200
    assert calls[0]["mode"] is None
    assert calls[0]["topic"] is None


@pytest.mark.parametrize("mode", ["debate", "FREE", "", 1])
def test_buddy_chat_rejects_unknown_mode(monkeypatch, mode):
    calls = _capture_calls(monkeypatch)

    response = client.post(
        "/buddy/chat",
        json={"history": [], "message": "Hi", "level": "B1", "mode": mode},
    )

    assert response.status_code == 422
    assert calls == []


def test_buddy_chat_rejects_topic_over_300_characters(monkeypatch):
    calls = _capture_calls(monkeypatch)

    response = client.post(
        "/buddy/chat",
        json={"history": [], "message": "Hi", "level": "B1", "mode": "topic", "topic": "a" * 301},
    )

    assert response.status_code == 422
    assert calls == []


def test_buddy_chat_accepts_topic_of_exactly_300_characters(monkeypatch):
    calls = _capture_calls(monkeypatch)

    response = client.post(
        "/buddy/chat",
        json={"history": [], "message": "Hi", "level": "B1", "mode": "topic", "topic": "a" * 300},
    )

    assert response.status_code == 200
    assert calls[0]["topic"] == "a" * 300


def test_buddy_chat_counts_topic_length_in_characters_not_bytes(monkeypatch):
    # 300 Cyrillic letters are 600 UTF-8 bytes but 300 characters.
    calls = _capture_calls(monkeypatch)

    response = client.post(
        "/buddy/chat",
        json={"history": [], "message": "Hi", "level": "B1", "mode": "topic", "topic": "ж" * 300},
    )

    assert response.status_code == 200
    assert calls[0]["topic"] == "ж" * 300


def test_buddy_chat_ignores_unknown_extra_fields(monkeypatch):
    # A newer client than this server (or the other way round) must not break:
    # unknown fields are dropped, not rejected.
    calls = _capture_calls(monkeypatch)

    response = client.post(
        "/buddy/chat",
        json={
            "history": [],
            "message": "Hi",
            "level": "B1",
            "mode": "ielts",
            "difficulty": "hard",
            "client_version": "2.0.0",
        },
    )

    assert response.status_code == 200
    assert calls[0]["mode"] == "ielts"
    assert "difficulty" not in calls[0]
    assert "client_version" not in calls[0]
