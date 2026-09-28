import os
from collections.abc import Mapping

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from app.openrouter_client import OpenRouterError, RateLimitedError, get_buddy_reply
from app.schemas import BuddyReply, ChatRequest

# Loads server/.env (per the README's `cp .env.example .env` step) into the
# process environment. Without this, OPENROUTER_API_KEY is never set even
# when .env has a real key, since `uv run` does not auto-load .env files.
load_dotenv()

_TRUTHY = {"1", "true", "yes", "on"}
_FALSY = {"", "0", "false", "no", "off"}


def validate_app_token_config(env: Mapping[str, str]) -> None:
    """Fail closed if REQUIRE_APP_TOKEN is set but APP_TOKEN is missing.

    ``_check_app_token`` (below) is fail-open by design for local dev: an
    unset ``APP_TOKEN`` means no auth gate at all. That is dangerous for the
    Render deployment (ST-29) - if ``APP_TOKEN`` is ever cleared or left
    blank in the dashboard's Environment tab, `/buddy/chat` would silently
    reopen with no error, no log, no signal (ST-37).

    ``REQUIRE_APP_TOKEN`` is the opt-in flag (set to ``1`` in render.yaml)
    that turns that silent reopen into a startup crash instead: called at
    import time, before the app object even exists, so uvicorn refuses to
    start rather than serve unauthenticated traffic. Local dev leaves the
    flag unset and keeps today's fail-open behavior unchanged.

    Raises:
        ValueError: REQUIRE_APP_TOKEN is set to a value that is neither a
            recognised truthy nor falsy token (e.g. a typo like "ture") -
            rejected rather than silently treated as fail-open.
        RuntimeError: REQUIRE_APP_TOKEN is truthy and APP_TOKEN is unset,
            empty, or whitespace-only.
    """
    raw_flag = env.get("REQUIRE_APP_TOKEN", "")
    flag = raw_flag.strip().lower()
    if flag in _TRUTHY:
        require = True
    elif flag in _FALSY:
        require = False
    else:
        raise ValueError(
            f"REQUIRE_APP_TOKEN={raw_flag!r} is not a recognised boolean "
            f"value (expected one of {sorted(_TRUTHY)} or {sorted(_FALSY)})."
        )

    if require and not env.get("APP_TOKEN", "").strip():
        raise RuntimeError(
            "REQUIRE_APP_TOKEN is set but APP_TOKEN is unset or empty. "
            "Refusing to start: this would otherwise serve /buddy/chat "
            "with no auth gate. Set APP_TOKEN (Render dashboard "
            "Environment tab) or unset REQUIRE_APP_TOKEN for local dev."
        )


validate_app_token_config(os.environ)

app = FastAPI(title="Study Buddy Server")

# ALLOWED_ORIGINS is a comma-separated allowlist. Unset -> any localhost
# port (so `flutter run -d chrome` keeps working unconfigured in dev).
_allowed_origins_env = os.environ.get("ALLOWED_ORIGINS")
if _allowed_origins_env:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[o.strip() for o in _allowed_origins_env.split(",") if o.strip()],
        allow_methods=["*"],
        allow_headers=["*"],
    )
else:
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
        allow_methods=["*"],
        allow_headers=["*"],
    )


def _check_app_token(x_app_token: str | None = Header(default=None)) -> None:
    # APP_TOKEN unset -> no auth gate (local dev). Set it to require callers
    # to send a matching X-App-Token header — not a real secret (it ships
    # inside the APK), just enough to stop random traffic burning the
    # OpenRouter daily quota (see spec :96-98).
    expected = os.environ.get("APP_TOKEN")
    if expected and x_app_token != expected:
        raise HTTPException(status_code=401, detail="Invalid or missing app token.")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/buddy/chat", response_model=BuddyReply, dependencies=[Depends(_check_app_token)])
async def buddy_chat(request: ChatRequest) -> BuddyReply:
    history = [m.model_dump() for m in request.history]
    try:
        reply = await get_buddy_reply(history, request.message, request.level)
    except RateLimitedError:
        raise HTTPException(
            status_code=429,
            detail="Daily practice limit reached, try again tomorrow.",
        )
    except OpenRouterError:
        raise HTTPException(
            status_code=502,
            detail="Couldn't reach your practice partner right now.",
        )
    return BuddyReply(**reply)
