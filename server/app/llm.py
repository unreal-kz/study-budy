"""Picks the LLM provider (LLM_PROVIDER) and forwards the buddy reply call to it."""

import os
from collections.abc import Mapping

from app import anthropic_client, openrouter_client

PROVIDERS = ("openrouter", "anthropic")
DEFAULT_PROVIDER = "openrouter"


def resolve_provider(env: Mapping[str, str]) -> str:
    """Return the configured provider; unset or blank means the default.

    Raises:
        ValueError: LLM_PROVIDER is set to something that is not a known
            provider (e.g. a typo) - rejected rather than silently falling
            back to a different provider than the one that was asked for.
    """
    raw = env.get("LLM_PROVIDER", "")
    provider = raw.strip().lower() or DEFAULT_PROVIDER
    if provider not in PROVIDERS:
        raise ValueError(
            f"LLM_PROVIDER={raw!r} is not a recognised provider "
            f"(expected one of {list(PROVIDERS)})."
        )
    return provider


def validate_llm_config(env: Mapping[str, str]) -> None:
    """Fail at startup if the selected provider can't possibly work.

    Called at import time from app.main, like validate_app_token_config: a
    missing key then crashes the deploy instead of turning every
    ``/buddy/chat`` call into a 502.

    Raises:
        ValueError: LLM_PROVIDER is not a recognised provider.
        RuntimeError: LLM_PROVIDER is ``anthropic`` and ANTHROPIC_API_KEY is
            unset, empty, or whitespace-only.
    """
    if resolve_provider(env) == "anthropic" and not env.get("ANTHROPIC_API_KEY", "").strip():
        raise RuntimeError(
            "LLM_PROVIDER=anthropic but ANTHROPIC_API_KEY is unset or empty. "
            "Set ANTHROPIC_API_KEY or switch LLM_PROVIDER back to openrouter."
        )


async def get_buddy_reply(
    history: list[dict],
    message: str,
    level: str,
    mode: str | None = None,
    topic: str | None = None,
) -> dict:
    """Get a buddy reply from the configured provider."""
    if resolve_provider(os.environ) == "anthropic":
        return await anthropic_client.get_buddy_reply(
            history, message, level, mode=mode, topic=topic
        )
    return await openrouter_client.get_buddy_reply(
        history, message, level, mode=mode, topic=topic
    )
