"""Claude (Anthropic Messages API) backend for the AI Buddy reply."""

import logging
import os
from functools import lru_cache

import anthropic
from pydantic import ValidationError

from app.llm_errors import LLMError, RateLimitedError
from app.prompts import (
    CORRECTION_DESCRIPTION,
    EXPLANATION_DESCRIPTION,
    REPLY_DESCRIPTION,
    build_system_prompt,
    fallback_reply,
)
from app.schemas import BuddyReply

logger = logging.getLogger(__name__)

MODEL = "claude-sonnet-5-5"
# Generous for a short chat reply: the cap also covers any adaptive-thinking
# tokens, and a response cut off by it is unusable JSON.
MAX_TOKENS = 2048
EFFORT = "low"
# Flutter sends the whole conversation on every request; bound what is billed.
MAX_HISTORY_MESSAGES = 20
# Same ~30s-per-attempt envelope the 90s Flutter timeout was sized for
# (lib/data/buddy_chat_api.dart), with one retry on 429/5xx/connection errors.
CLIENT_TIMEOUT_S = 30.0
CLIENT_MAX_RETRIES = 1

_ROLES = ("user", "assistant")
# The Messages API needs the first message to be a user turn; the v2 Topic
# mode starts its history with the assistant's opener.
_CONVERSATION_START = "(The conversation has just started.)"


def _nullable_string(description: str) -> dict:
    return {"anyOf": [{"type": "string"}, {"type": "null"}], "description": description}


REPLY_SCHEMA = {
    "type": "object",
    "properties": {
        "reply": {"type": "string", "description": REPLY_DESCRIPTION},
        "correction": _nullable_string(CORRECTION_DESCRIPTION),
        "explanation": _nullable_string(EXPLANATION_DESCRIPTION),
    },
    "required": ["reply", "correction", "explanation"],
    "additionalProperties": False,
}


def _build_messages(history: list[dict], message: str) -> list[dict]:
    """Turn the client's history plus the new message into Messages API turns.

    The client controls ``role``; anything other than user/assistant is coerced
    to ``user`` so it can never act as a system message. Blank turns are
    dropped because the API rejects empty text content.
    """
    turns = [
        {"role": m["role"] if m["role"] in _ROLES else "user", "content": m["content"]}
        for m in history[-MAX_HISTORY_MESSAGES:]
        if m["content"].strip()
    ]
    turns.append({"role": "user", "content": message})
    if turns[0]["role"] != "user":
        turns.insert(0, {"role": "user", "content": _CONVERSATION_START})
    return turns


@lru_cache(maxsize=1)
def _get_client() -> anthropic.AsyncAnthropic:
    try:
        api_key = os.environ["ANTHROPIC_API_KEY"]
    except KeyError as exc:
        raise LLMError("ANTHROPIC_API_KEY is not set") from exc
    return anthropic.AsyncAnthropic(
        api_key=api_key, timeout=CLIENT_TIMEOUT_S, max_retries=CLIENT_MAX_RETRIES
    )


async def get_buddy_reply(
    history: list[dict],
    message: str,
    level: str,
    mode: str | None = None,
    topic: str | None = None,
) -> dict:
    """Call Claude for a buddy reply.

    Returns the same ``{"reply", "correction", "explanation"}`` dict as the
    OpenRouter client. A refusal, a cut-off or an unparseable response falls
    back to the plain-text reply with correction/explanation set to null.
    Raises RateLimitedError on 429 and LLMError on any other API failure.
    """
    client = _get_client()
    try:
        response = await client.messages.create(
            model=MODEL,
            max_tokens=MAX_TOKENS,
            system=build_system_prompt(level, mode, topic),
            messages=_build_messages(history, message),
            output_config={
                "effort": EFFORT,
                "format": {"type": "json_schema", "schema": REPLY_SCHEMA},
            },
        )
    except anthropic.RateLimitError as exc:
        logger.warning("Anthropic rate limit reached request_id=%s", exc.request_id)
        raise RateLimitedError("Anthropic rate limit reached") from exc
    except anthropic.APIStatusError as exc:
        logger.error(
            "Anthropic API error status=%s request_id=%s", exc.status_code, exc.request_id
        )
        raise LLMError(f"Anthropic returned {exc.status_code}") from exc
    except anthropic.APIConnectionError as exc:
        logger.error("Couldn't reach Anthropic: %s", exc)
        raise LLMError(f"Couldn't reach Anthropic: {exc}") from exc

    logger.info(
        "Anthropic reply request_id=%s model=%s stop_reason=%s input_tokens=%s output_tokens=%s",
        response._request_id,
        response.model,
        response.stop_reason,
        response.usage.input_tokens,
        response.usage.output_tokens,
    )
    if response.stop_reason != "end_turn":
        logger.warning(
            "Anthropic reply not usable stop_reason=%s request_id=%s",
            response.stop_reason,
            response._request_id,
        )
        return fallback_reply()

    text = next((b.text for b in response.content if b.type == "text"), None)
    if text is None:
        logger.warning("Anthropic reply has no text block request_id=%s", response._request_id)
        return fallback_reply()
    try:
        return BuddyReply.model_validate_json(text).model_dump()
    except ValidationError:
        logger.warning("Anthropic reply failed validation request_id=%s", response._request_id)
        return fallback_reply()
