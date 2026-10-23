# server/tests/test_llm_dispatch.py
from unittest.mock import AsyncMock

import pytest

from app import llm
from app.llm import resolve_provider, validate_llm_config


@pytest.mark.parametrize("env", [{}, {"LLM_PROVIDER": ""}, {"LLM_PROVIDER": "   "}])
def test_resolve_provider_defaults_to_openrouter(env):
    assert resolve_provider(env) == "openrouter"


@pytest.mark.parametrize(
    ("raw", "expected"),
    [("anthropic", "anthropic"), (" Anthropic ", "anthropic"), ("OPENROUTER", "openrouter")],
)
def test_resolve_provider_is_case_and_space_insensitive(raw, expected):
    assert resolve_provider({"LLM_PROVIDER": raw}) == expected


def test_resolve_provider_rejects_unknown_value():
    with pytest.raises(ValueError, match="LLM_PROVIDER"):
        resolve_provider({"LLM_PROVIDER": "anthropc"})


@pytest.mark.parametrize("key", [None, "", "   "])
def test_validate_llm_config_requires_key_for_anthropic(key):
    env = {"LLM_PROVIDER": "anthropic"}
    if key is not None:
        env["ANTHROPIC_API_KEY"] = key

    with pytest.raises(RuntimeError, match="ANTHROPIC_API_KEY"):
        validate_llm_config(env)


def test_validate_llm_config_accepts_anthropic_with_key():
    validate_llm_config({"LLM_PROVIDER": "anthropic", "ANTHROPIC_API_KEY": "sk-test"})


def test_validate_llm_config_needs_no_anthropic_key_by_default():
    validate_llm_config({})
    validate_llm_config({"LLM_PROVIDER": "openrouter"})


def test_validate_llm_config_rejects_unknown_provider():
    with pytest.raises(ValueError, match="LLM_PROVIDER"):
        validate_llm_config({"LLM_PROVIDER": "gpt"})


@pytest.fixture
def providers(monkeypatch):
    openrouter = AsyncMock(return_value={"reply": "from openrouter"})
    anthropic = AsyncMock(return_value={"reply": "from anthropic"})
    monkeypatch.setattr("app.llm.openrouter_client.get_buddy_reply", openrouter)
    monkeypatch.setattr("app.llm.anthropic_client.get_buddy_reply", anthropic)
    return openrouter, anthropic


async def test_dispatch_uses_openrouter_when_unset(monkeypatch, providers):
    openrouter, anthropic = providers
    monkeypatch.delenv("LLM_PROVIDER", raising=False)

    result = await llm.get_buddy_reply([], "Hi", "B1", mode="topic", topic="food")

    assert result == {"reply": "from openrouter"}
    openrouter.assert_awaited_once_with([], "Hi", "B1", mode="topic", topic="food")
    anthropic.assert_not_awaited()


async def test_dispatch_uses_anthropic_when_selected(monkeypatch, providers):
    openrouter, anthropic = providers
    monkeypatch.setenv("LLM_PROVIDER", "anthropic")

    result = await llm.get_buddy_reply([], "Hi", "B1", mode="ielts")

    assert result == {"reply": "from anthropic"}
    anthropic.assert_awaited_once_with([], "Hi", "B1", mode="ielts", topic=None)
    openrouter.assert_not_awaited()
