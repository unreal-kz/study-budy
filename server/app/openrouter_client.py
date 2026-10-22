import json
import os

import httpx

from app.llm_errors import LLMError, RateLimitedError
from app.prompts import (  # noqa: F401 - re-exported: tests import these from here
    BUDDY_REPLY_SCHEMA,
    IELTS_INSTRUCTION,
    SYSTEM_PROMPT_TEMPLATE,
    TOPIC_INSTRUCTION_NO_TOPIC,
    TOPIC_INSTRUCTION_TEMPLATE,
    fallback_reply,
)
from app.prompts import build_system_prompt as _build_system_prompt

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
MODEL = "nvidia/nemotron-3-super-120b-a12b:free"

# Kept under the old name: callers and tests import it from this module.
OpenRouterError = LLMError


def _build_payload(
    history: list[dict],
    message: str,
    level: str,
    mode: str | None = None,
    topic: str | None = None,
) -> dict:
    messages = [
        {"role": "system", "content": _build_system_prompt(level, mode, topic)}
    ]
    messages.extend(history)
    messages.append({"role": "user", "content": message})
    return {
        "model": MODEL,
        "messages": messages,
        "response_format": {
            "type": "json_schema",
            "json_schema": {
                "name": "buddy_reply",
                "strict": True,
                "schema": BUDDY_REPLY_SCHEMA,
            },
        },
    }


def _extract_content(response: httpx.Response) -> str | None:
    try:
        return response.json()["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError, json.JSONDecodeError):
        return None


def _try_parse_json(content: str) -> dict | None:
    try:
        return json.loads(content)
    except (json.JSONDecodeError, TypeError):
        return None


def _is_valid_buddy_reply(parsed: object) -> bool:
    if not isinstance(parsed, dict):
        return False
    if not isinstance(parsed.get("reply"), str):
        return False
    if parsed.get("correction") is not None and not isinstance(parsed.get("correction"), str):
        return False
    if parsed.get("explanation") is not None and not isinstance(parsed.get("explanation"), str):
        return False
    return True


async def get_buddy_reply(
    history: list[dict],
    message: str,
    level: str,
    mode: str | None = None,
    topic: str | None = None,
) -> dict:
    """Call OpenRouter for a buddy reply.

    ``mode`` ("free" | "topic" | "ielts") and ``topic`` are optional; with
    ``mode`` None or "free" the system prompt is the same as before modes.

    Retries once on a malformed/non-schema JSON body, then falls back to a
    plain-text reply with correction/explanation set to null. Raises
    RateLimitedError on 429 and OpenRouterError on any other non-200 status.
    """
    payload = _build_payload(history, message, level, mode, topic)
    try:
        api_key = os.environ["OPENROUTER_API_KEY"]
    except KeyError as exc:
        raise OpenRouterError("OPENROUTER_API_KEY is not set") from exc
    headers = {"Authorization": f"Bearer {api_key}"}

    for _attempt in range(2):
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(OPENROUTER_URL, json=payload, headers=headers)
        except httpx.RequestError as exc:
            raise OpenRouterError(f"Couldn't reach OpenRouter: {exc}") from exc

        if response.status_code == 429:
            raise RateLimitedError("OpenRouter rate limit reached")
        if response.status_code != 200:
            raise OpenRouterError(
                f"OpenRouter returned {response.status_code}: {response.text}"
            )

        content = _extract_content(response)
        parsed = _try_parse_json(content) if content is not None else None
        if parsed is not None and _is_valid_buddy_reply(parsed):
            return parsed

    return fallback_reply()
