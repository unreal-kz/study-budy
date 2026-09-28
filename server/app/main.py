from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from app.openrouter_client import OpenRouterError, RateLimitedError, get_buddy_reply
from app.schemas import BuddyReply, ChatRequest

# Loads server/.env (per the README's `cp .env.example .env` step) into the
# process environment. Without this, OPENROUTER_API_KEY is never set even
# when .env has a real key, since `uv run` does not auto-load .env files.
load_dotenv()

app = FastAPI(title="Study Buddy Server")

# Local dev only — allow any origin so the Flutter app (any platform/port)
# can reach this. Tighten before any public deployment.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/buddy/chat", response_model=BuddyReply)
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
