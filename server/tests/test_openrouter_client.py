# server/tests/test_openrouter_client.py
import json
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.openrouter_client import (
    OpenRouterError,
    RateLimitedError,
    get_buddy_reply,
)


def _fake_response(status_code: int, content: str | None = None, text: str = ""):
    response = MagicMock()
    response.status_code = status_code
    response.text = text
    if content is not None:
        response.json.return_value = {
            "choices": [{"message": {"content": content}}]
        }
    return response


@pytest.mark.asyncio
async def test_valid_json_reply_returned_on_first_try():
    valid = json.dumps(
        {"reply": "Nice!", "correction": None, "explanation": None}
    )
    mock_client = AsyncMock()
    mock_client.__aenter__.return_value.post = AsyncMock(
        return_value=_fake_response(200, valid)
    )
    with patch("app.openrouter_client.httpx.AsyncClient", return_value=mock_client):
        result = await get_buddy_reply(history=[], message="Hi", level="B1")
    assert result == {"reply": "Nice!", "correction": None, "explanation": None}


@pytest.mark.asyncio
async def test_malformed_json_retries_once_then_succeeds():
    valid = json.dumps(
        {"reply": "Nice!", "correction": "Nice job!", "explanation": "grammar ok"}
    )
    mock_client = AsyncMock()
    mock_client.__aenter__.return_value.post = AsyncMock(
        side_effect=[_fake_response(200, "not json"), _fake_response(200, valid)]
    )
    with patch("app.openrouter_client.httpx.AsyncClient", return_value=mock_client):
        result = await get_buddy_reply(history=[], message="Hi", level="B1")
    assert result["reply"] == "Nice!"
    assert mock_client.__aenter__.return_value.post.await_count == 2


@pytest.mark.asyncio
async def test_malformed_json_twice_falls_back_gracefully():
    mock_client = AsyncMock()
    mock_client.__aenter__.return_value.post = AsyncMock(
        return_value=_fake_response(200, "not json at all")
    )
    with patch("app.openrouter_client.httpx.AsyncClient", return_value=mock_client):
        result = await get_buddy_reply(history=[], message="Hi", level="B1")
    assert result["correction"] is None
    assert result["explanation"] is None
    assert isinstance(result["reply"], str) and result["reply"]


@pytest.mark.asyncio
async def test_rate_limit_raises_rate_limited_error():
    mock_client = AsyncMock()
    mock_client.__aenter__.return_value.post = AsyncMock(
        return_value=_fake_response(429, text="rate limited")
    )
    with patch("app.openrouter_client.httpx.AsyncClient", return_value=mock_client):
        with pytest.raises(RateLimitedError):
            await get_buddy_reply(history=[], message="Hi", level="B1")


@pytest.mark.asyncio
async def test_other_error_status_raises_openrouter_error():
    mock_client = AsyncMock()
    mock_client.__aenter__.return_value.post = AsyncMock(
        return_value=_fake_response(500, text="server error")
    )
    with patch("app.openrouter_client.httpx.AsyncClient", return_value=mock_client):
        with pytest.raises(OpenRouterError):
            await get_buddy_reply(history=[], message="Hi", level="B1")
