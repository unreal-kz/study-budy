import json
import os

import httpx

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
MODEL = "google/gemma-4-31b-it:free"

BUDDY_REPLY_SCHEMA = {
    "type": "object",
    "properties": {
        "reply": {
            "type": "string",
            "description": "Conversational reply continuing the practice conversation",
        },
        "correction": {
            "type": ["string", "null"],
            "description": (
                "Corrected version of the user's message if it has a "
                "grammar mistake, otherwise null"
            ),
        },
        "explanation": {
            "type": ["string", "null"],
            "description": "Brief explanation of the correction, otherwise null",
        },
    },
    "required": ["reply", "correction", "explanation"],
    "additionalProperties": False,
}

SYSTEM_PROMPT_TEMPLATE = (
    "You are a friendly English-speaking practice partner for a student in "
    "Kazakhstan at CEFR level {level}. Keep the conversation going naturally "
    "on whatever topic the student raises. If their message has a grammar "
    "mistake, also provide a corrected version and a short explanation; if "
    "there is no mistake, set correction and explanation to null."
)


class OpenRouterError(Exception):
    """Raised when OpenRouter can't be reached or returns an error status."""


class RateLimitedError(OpenRouterError):
    """Raised when OpenRouter returns 429 (free-tier rate limit)."""


def _build_payload(history: list[dict], message: str, level: str) -> dict:
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT_TEMPLATE.format(level=level)}
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


def _try_parse_json(content: str) -> dict | None:
    try:
        return json.loads(content)
    except (json.JSONDecodeError, TypeError):
        return None


def _is_valid_buddy_reply(parsed: object) -> bool:
    return isinstance(parsed, dict) and isinstance(parsed.get("reply"), str)


async def get_buddy_reply(history: list[dict], message: str, level: str) -> dict:
    """Call OpenRouter for a buddy reply.

    Retries once on a malformed/non-schema JSON body, then falls back to a
    plain-text reply with correction/explanation set to null. Raises
    RateLimitedError on 429 and OpenRouterError on any other non-200 status.
    """
    payload = _build_payload(history, message, level)
    headers = {"Authorization": f"Bearer {os.environ['OPENROUTER_API_KEY']}"}

    for _attempt in range(2):
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(OPENROUTER_URL, json=payload, headers=headers)

        if response.status_code == 429:
            raise RateLimitedError("OpenRouter rate limit reached")
        if response.status_code != 200:
            raise OpenRouterError(
                f"OpenRouter returned {response.status_code}: {response.text}"
            )

        content = response.json()["choices"][0]["message"]["content"]
        parsed = _try_parse_json(content)
        if parsed is not None and _is_valid_buddy_reply(parsed):
            return parsed

    return {
        "reply": "Let's keep practicing! (I couldn't format that reply properly.)",
        "correction": None,
        "explanation": None,
    }
