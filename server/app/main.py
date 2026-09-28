import os

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from app.openrouter_client import OpenRouterError, RateLimitedError, get_buddy_reply
from app.schemas import BuddyReply, ChatRequest

# Loads server/.env (per the README's `cp .env.example .env` step) into the
# process environment. Without this, OPENROUTER_API_KEY is never set even
# when .env has a real key, since `uv run` does not auto-load .env files.
load_dotenv()

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
