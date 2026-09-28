# Study Buddy MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a working, demoable Study Buddy app: five-tab Flutter app (Android/iOS/Web) with a real text-based AI Buddy (grammar-corrected English practice via a free model) and mocked Find a Buddy / Buddy Chat / Community.

**Architecture:** Flutter app talks to a thin FastAPI backend (`server/`) only for the AI Buddy feature; the backend is the sole holder of the OpenRouter API key and proxies to `google/gemma-4-31b-it:free`. Everything else (profile, chat history, daily progress) lives in on-device `shared_preferences`, and Find a Buddy / Community are read-only JSON fixtures bundled as Flutter assets.

**Tech Stack:** Flutter 3.47 / Dart 3.13, `go_router` 18.0.1, `provider` 6.1.5+1, `shared_preferences` 2.5.5, `http` 1.6.0 (client), Python 3.12+ via `uv`, FastAPI, `httpx` (server-side HTTP to OpenRouter), `pytest` + `pytest-asyncio` + `pytest-mock`.

**Spec:** `docs/superpowers/specs/2026-09-28-study-buddy-mvp-design.md`

## Global Constraints

- No paid APIs — the AI Buddy feature uses `google/gemma-4-31b-it:free` via OpenRouter only.
- `OPENROUTER_API_KEY` lives only in `server/.env` (gitignored) — never in the Flutter client, never committed.
- Local storage is `shared_preferences` only — no `sqflite`/`drift` (no native Web support without an experimental package; see spec).
- Flutter state management is `provider`; routing is `go_router`. No other state/routing package.
- Backend is Python 3.12+, managed with `uv`, framework FastAPI.
- Voice input/output, a real multi-user backend, and public deployment are explicitly out of scope for this plan (see spec's Out of scope).
- Each task ends with a commit, per this plan's step structure — this is how the plan produces a reviewable, working history; flag before execution if that's not wanted.

## Review Focus

- A malformed / non-schema-conforming JSON reply from the model — the backend must retry once, then fall back to a plain-text reply (`correction: null`), never crash the request. (Task 2)
- OpenRouter's free-tier rate limit (429) — the user sees "daily practice limit reached, try again tomorrow," not a raw error. (Task 2/3)
- The network call to the backend fails while sending a message — the user's typed message must already be safe in local storage, not lost. (Task 8)
- The backend is completely unreachable (not running) — only the AI Buddy tab degrades; Home, Find a Buddy, Community, and Progress keep working fully offline. (Task 12)
- A gap in `progress_daily` (a missed day) — the streak must reset at the gap, not count through it or overcount. (Task 5)

---

## Backend (`server/`)

### Task 1: FastAPI project skeleton + health check

**Files:**
- Create: `server/pyproject.toml`
- Create: `server/app/__init__.py`
- Create: `server/app/main.py`
- Create: `server/tests/__init__.py`
- Test: `server/tests/test_health.py`
- Create: `server/.env.example`
- Modify: `study-budy/.gitignore` (repo root, already exists)

**Interfaces:**
- Produces: `app.main:app` (a `FastAPI` instance), a `GET /health` route returning `{"status": "ok"}`.

- [ ] **Step 1: Create the `server/` project**

```bash
cd /Users/baubek/Desktop/GITHUB/Daryn-Projects/study-budy
mkdir -p server/app server/tests
```

- [ ] **Step 2: Write `server/pyproject.toml`**

```toml
[project]
name = "study-buddy-server"
version = "0.1.0"
description = "Thin backend proxy for Study Buddy's AI Buddy feature"
requires-python = ">=3.12"
dependencies = [
    "fastapi>=0.141.1",
    "uvicorn[standard]>=0.54.0",
    "httpx>=0.28.1",
    "python-dotenv>=1.2.3",
]

[dependency-groups]
dev = [
    "pytest>=9.1.1",
    "pytest-asyncio>=1.4.0",
    "pytest-mock>=3.16.0",
]

[tool.pytest.ini_options]
asyncio_mode = "auto"
```

- [ ] **Step 3: Write the failing test**

```python
# server/tests/test_health.py
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_returns_ok():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
```

- [ ] **Step 4: Create empty package files**

```bash
touch server/app/__init__.py server/tests/__init__.py
```

- [ ] **Step 5: Run test to verify it fails**

Run: `cd server && uv run pytest tests/test_health.py -v`
Expected: FAIL (`ModuleNotFoundError: No module named 'app.main'` or similar — `app/main.py` doesn't exist yet)

- [ ] **Step 6: Write `server/app/main.py`**

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

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
```

- [ ] **Step 7: Run test to verify it passes**

Run: `cd server && uv run pytest tests/test_health.py -v`
Expected: PASS

- [ ] **Step 8: Write `server/.env.example` (committed placeholder, not the real key)**

```
OPENROUTER_API_KEY=your-openrouter-key-here
```

- [ ] **Step 9: Extend the repo's `.gitignore` for the Python backend**

Append to `/Users/baubek/Desktop/GITHUB/Daryn-Projects/study-budy/.gitignore`:

```
# Python backend (server/)
server/.venv/
server/__pycache__/
server/**/__pycache__/
server/.pytest_cache/
server/.env
```

- [ ] **Step 10: Verify `.env` is actually ignored**

Run: `cd /Users/baubek/Desktop/GITHUB/Daryn-Projects/study-budy && touch server/.env && git check-ignore -v server/.env`
Expected: prints the matching `.gitignore` rule (confirms it's ignored, not merely assumed)

- [ ] **Step 11: Commit**

```bash
cd /Users/baubek/Desktop/GITHUB/Daryn-Projects/study-budy
git add server/pyproject.toml server/app/__init__.py server/app/main.py \
        server/tests/__init__.py server/tests/test_health.py \
        server/.env.example .gitignore
git commit -m "server: FastAPI skeleton with health check"
```

---

### Task 2: Pydantic schemas + OpenRouter client (with fallback/retry)

**Files:**
- Create: `server/app/schemas.py`
- Create: `server/app/openrouter_client.py`
- Test: `server/tests/test_openrouter_client.py`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `HistoryMessage`, `ChatRequest`, `BuddyReply` (Pydantic models in `app.schemas`); `get_buddy_reply(history: list[dict], message: str, level: str) -> dict` (async), `OpenRouterError`, `RateLimitedError` (in `app.openrouter_client`) — Task 3 imports all of these.

- [ ] **Step 1: Write `server/app/schemas.py`**

```python
from pydantic import BaseModel


class HistoryMessage(BaseModel):
    role: str  # "user" | "assistant"
    content: str


class ChatRequest(BaseModel):
    history: list[HistoryMessage]
    message: str
    level: str  # "A1" | "A2" | "B1" | "B2"


class BuddyReply(BaseModel):
    reply: str
    correction: str | None = None
    explanation: str | None = None
```

- [ ] **Step 2: Write the failing tests for the OpenRouter client**

```python
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
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd server && uv run pytest tests/test_openrouter_client.py -v`
Expected: FAIL (`ModuleNotFoundError: No module named 'app.openrouter_client'`)

- [ ] **Step 4: Write `server/app/openrouter_client.py`**

```python
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd server && uv run pytest tests/test_openrouter_client.py -v`
Expected: PASS (all 5 tests)

- [ ] **Step 6: Commit**

```bash
cd /Users/baubek/Desktop/GITHUB/Daryn-Projects/study-budy
git add server/app/schemas.py server/app/openrouter_client.py \
        server/tests/test_openrouter_client.py
git commit -m "server: schemas + OpenRouter client with retry/fallback"
```

---

### Task 3: `POST /buddy/chat` endpoint

**Files:**
- Modify: `server/app/main.py`
- Test: `server/tests/test_buddy_chat.py`

**Interfaces:**
- Consumes: `ChatRequest`, `BuddyReply` (`app.schemas`); `get_buddy_reply`, `OpenRouterError`, `RateLimitedError` (`app.openrouter_client`) — from Task 2.
- Produces: `POST /buddy/chat` route on `app.main:app` — the URL and shape Flutter's `BuddyChatApi` (Task 7) calls.

- [ ] **Step 1: Write the failing tests**

```python
# server/tests/test_buddy_chat.py
from unittest.mock import AsyncMock

from fastapi.testclient import TestClient

from app.main import app
from app.openrouter_client import OpenRouterError, RateLimitedError

client = TestClient(app)


def test_buddy_chat_returns_reply(monkeypatch):
    async def fake_get_buddy_reply(history, message, level):
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
    async def raise_rate_limited(history, message, level):
        raise RateLimitedError("nope")

    monkeypatch.setattr("app.main.get_buddy_reply", raise_rate_limited)

    response = client.post(
        "/buddy/chat", json={"history": [], "message": "Hi", "level": "B1"}
    )
    assert response.status_code == 429
    assert "tomorrow" in response.json()["detail"]


def test_buddy_chat_upstream_error_returns_502(monkeypatch):
    async def raise_openrouter_error(history, message, level):
        raise OpenRouterError("boom")

    monkeypatch.setattr("app.main.get_buddy_reply", raise_openrouter_error)

    response = client.post(
        "/buddy/chat", json={"history": [], "message": "Hi", "level": "B1"}
    )
    assert response.status_code == 502
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server && uv run pytest tests/test_buddy_chat.py -v`
Expected: FAIL (404 — no `/buddy/chat` route yet)

- [ ] **Step 3: Add the endpoint to `server/app/main.py`**

Append (keep the existing `app`, CORS, and `/health` route from Task 1):

```python
from fastapi import HTTPException

from app.openrouter_client import OpenRouterError, RateLimitedError, get_buddy_reply
from app.schemas import BuddyReply, ChatRequest


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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server && uv run pytest tests/test_buddy_chat.py -v`
Expected: PASS (all 3 tests)

- [ ] **Step 5: Run the full backend test suite**

Run: `cd server && uv run pytest -v`
Expected: all tests across `test_health.py`, `test_openrouter_client.py`, `test_buddy_chat.py` PASS

- [ ] **Step 6: Manual smoke test against the real OpenRouter API**

```bash
cd server
echo "OPENROUTER_API_KEY=<your real key>" > .env
uv run uvicorn app.main:app --reload --port 8000
```

In another terminal:

```bash
curl -s -X POST http://localhost:8000/buddy/chat \
  -H "Content-Type: application/json" \
  -d '{"history": [], "message": "I go to school yesterday.", "level": "A2"}'
```

Expected: a JSON body with `reply` and a non-null `correction`/`explanation` pointing out the tense mistake ("went", not "go"). This is the first real call against the free-tier model — confirms the API key and OpenRouter integration work end to end, not just the mocked tests.

- [ ] **Step 7: Commit**

```bash
cd /Users/baubek/Desktop/GITHUB/Daryn-Projects/study-budy
git add server/app/main.py server/tests/test_buddy_chat.py
git commit -m "server: POST /buddy/chat endpoint"
```

---

## Flutter — data layer

### Task 4: Core data models (Profile, ChatMessage, ProgressEntry)

**Files:**
- Create: `lib/models/profile.dart`
- Create: `lib/models/chat_message.dart`
- Create: `lib/models/progress_entry.dart`
- Test: `test/models/profile_test.dart`
- Test: `test/models/chat_message_test.dart`
- Test: `test/models/progress_entry_test.dart`

**Interfaces:**
- Produces: `Profile` (`name`, `level`, `onboardingComplete`, `Profile.empty`, `toJson`/`fromJson`, `copyWith`), `ChatMessage` (`id`, `sender`, `text`, `correction`, `explanation`, `createdAt`, `toJson`/`fromJson`), `ProgressEntry` (`date`, `speakingTimeSeconds`, `challengesCompleted`, `newWords`, `toJson`/`fromJson`, `copyWith`) — every later data/state task imports these.

- [ ] **Step 1: Write the failing tests**

```dart
// test/models/profile_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:study_budy/models/profile.dart';

void main() {
  test('Profile round-trips through JSON', () {
    const profile = Profile(name: 'Daryn', level: 'B1', onboardingComplete: true);
    final restored = Profile.fromJson(profile.toJson());
    expect(restored.name, 'Daryn');
    expect(restored.level, 'B1');
    expect(restored.onboardingComplete, true);
  });

  test('Profile.empty has onboardingComplete false', () {
    expect(Profile.empty.onboardingComplete, false);
  });
}
```

```dart
// test/models/chat_message_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:study_budy/models/chat_message.dart';

void main() {
  test('ChatMessage round-trips through JSON, including nulls', () {
    final message = ChatMessage(
      id: '1',
      sender: 'user',
      text: 'Hello',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final restored = ChatMessage.fromJson(message.toJson());
    expect(restored.text, 'Hello');
    expect(restored.correction, isNull);
    expect(restored.createdAt, DateTime.utc(2026, 1, 1));
  });

  test('ChatMessage round-trips with correction/explanation set', () {
    final message = ChatMessage(
      id: '2',
      sender: 'ai',
      text: 'Nice!',
      correction: 'I went to school.',
      explanation: 'Past tense of go is went.',
      createdAt: DateTime.utc(2026, 1, 2),
    );
    final restored = ChatMessage.fromJson(message.toJson());
    expect(restored.correction, 'I went to school.');
    expect(restored.explanation, 'Past tense of go is went.');
  });
}
```

```dart
// test/models/progress_entry_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:study_budy/models/progress_entry.dart';

void main() {
  test('ProgressEntry round-trips through JSON', () {
    const entry = ProgressEntry(
      date: '2026-09-28',
      speakingTimeSeconds: 120,
      challengesCompleted: 1,
      newWords: 3,
    );
    final restored = ProgressEntry.fromJson(entry.toJson());
    expect(restored.date, '2026-09-28');
    expect(restored.speakingTimeSeconds, 120);
    expect(restored.newWords, 3);
  });

  test('copyWith adds to existing counts when given new values', () {
    const entry = ProgressEntry(date: '2026-09-28', newWords: 2);
    final updated = entry.copyWith(newWords: 5);
    expect(updated.newWords, 5);
    expect(updated.date, '2026-09-28');
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/models/ -r expanded`
Expected: FAIL (`Error: Not found: 'package:study_budy/models/profile.dart'` etc.)

- [ ] **Step 3: Write `lib/models/profile.dart`**

```dart
class Profile {
  const Profile({
    required this.name,
    required this.level,
    this.onboardingComplete = false,
  });

  final String name;
  final String level; // 'A1' | 'A2' | 'B1' | 'B2'
  final bool onboardingComplete;

  static const empty = Profile(name: '', level: 'A1', onboardingComplete: false);

  Profile copyWith({String? name, String? level, bool? onboardingComplete}) => Profile(
        name: name ?? this.name,
        level: level ?? this.level,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'level': level,
        'onboardingComplete': onboardingComplete,
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        name: json['name'] as String,
        level: json['level'] as String,
        onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      );
}
```

- [ ] **Step 4: Write `lib/models/chat_message.dart`**

```dart
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    this.correction,
    this.explanation,
    required this.createdAt,
  });

  final String id;
  final String sender; // 'user' | 'ai'
  final String text;
  final String? correction;
  final String? explanation;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'text': text,
        'correction': correction,
        'explanation': explanation,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        sender: json['sender'] as String,
        text: json['text'] as String,
        correction: json['correction'] as String?,
        explanation: json['explanation'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
```

- [ ] **Step 5: Write `lib/models/progress_entry.dart`**

```dart
class ProgressEntry {
  const ProgressEntry({
    required this.date,
    this.speakingTimeSeconds = 0,
    this.challengesCompleted = 0,
    this.newWords = 0,
  });

  final String date; // 'yyyy-MM-dd'
  final int speakingTimeSeconds;
  final int challengesCompleted;
  final int newWords;

  ProgressEntry copyWith({
    int? speakingTimeSeconds,
    int? challengesCompleted,
    int? newWords,
  }) =>
      ProgressEntry(
        date: date,
        speakingTimeSeconds: speakingTimeSeconds ?? this.speakingTimeSeconds,
        challengesCompleted: challengesCompleted ?? this.challengesCompleted,
        newWords: newWords ?? this.newWords,
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'speakingTimeSeconds': speakingTimeSeconds,
        'challengesCompleted': challengesCompleted,
        'newWords': newWords,
      };

  factory ProgressEntry.fromJson(Map<String, dynamic> json) => ProgressEntry(
        date: json['date'] as String,
        speakingTimeSeconds: json['speakingTimeSeconds'] as int? ?? 0,
        challengesCompleted: json['challengesCompleted'] as int? ?? 0,
        newWords: json['newWords'] as int? ?? 0,
      );
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/models/ -r expanded`
Expected: PASS (6 tests)

- [ ] **Step 7: Commit**

```bash
git add lib/models/profile.dart lib/models/chat_message.dart lib/models/progress_entry.dart \
        test/models/profile_test.dart test/models/chat_message_test.dart test/models/progress_entry_test.dart
git commit -m "flutter: core data models (Profile, ChatMessage, ProgressEntry)"
```

---

### Task 5: Repositories (Profile, Chat, Progress) over `shared_preferences`

**Files:**
- Add dependency: `shared_preferences: ^2.5.5` to `pubspec.yaml`
- Create: `lib/data/profile_repository.dart`
- Create: `lib/data/chat_repository.dart`
- Create: `lib/data/progress_repository.dart`
- Test: `test/data/profile_repository_test.dart`
- Test: `test/data/chat_repository_test.dart`
- Test: `test/data/progress_repository_test.dart`

**Interfaces:**
- Consumes: `Profile`, `ChatMessage`, `ProgressEntry` (Task 4).
- Produces: `ProfileRepository` (`load()`, `save(Profile)`), `ChatRepository` (`loadAll()`, `add(ChatMessage)`), `ProgressRepository` (`loadAll()`, `recordSession({date, speakingTimeSeconds, challengesCompleted, newWords})`, `currentStreak({DateTime? today})`) — Task 8 (providers) depends on all three.

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add shared_preferences`
Expected: `pubspec.yaml` gains `shared_preferences: ^2.5.5` (or newer compatible) and `flutter pub get` resolves cleanly.

- [ ] **Step 2: Write the failing tests**

```dart
// test/data/profile_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/profile_repository.dart';
import 'package:study_budy/models/profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load() returns Profile.empty when nothing saved', () async {
    final repo = ProfileRepository();
    final profile = await repo.load();
    expect(profile.onboardingComplete, false);
  });

  test('save() then load() round-trips the profile', () async {
    final repo = ProfileRepository();
    await repo.save(const Profile(name: 'Daryn', level: 'B1', onboardingComplete: true));
    final profile = await repo.load();
    expect(profile.name, 'Daryn');
    expect(profile.level, 'B1');
    expect(profile.onboardingComplete, true);
  });
}
```

```dart
// test/data/chat_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/chat_repository.dart';
import 'package:study_budy/models/chat_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loadAll() returns empty list initially', () async {
    final repo = ChatRepository();
    expect(await repo.loadAll(), isEmpty);
  });

  test('add() appends and preserves order', () async {
    final repo = ChatRepository();
    await repo.add(ChatMessage(
      id: '1', sender: 'user', text: 'Hi', createdAt: DateTime.utc(2026, 1, 1),
    ));
    await repo.add(ChatMessage(
      id: '2', sender: 'ai', text: 'Hello!', createdAt: DateTime.utc(2026, 1, 1, 0, 0, 1),
    ));
    final messages = await repo.loadAll();
    expect(messages.map((m) => m.id).toList(), ['1', '2']);
  });
}
```

```dart
// test/data/progress_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/progress_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('recordSession creates a new entry for a new date', () async {
    final repo = ProgressRepository();
    await repo.recordSession(date: '2026-09-28', newWords: 2);
    final entries = await repo.loadAll();
    expect(entries, hasLength(1));
    expect(entries.first.newWords, 2);
  });

  test('recordSession accumulates onto the same date', () async {
    final repo = ProgressRepository();
    await repo.recordSession(date: '2026-09-28', newWords: 2);
    await repo.recordSession(date: '2026-09-28', newWords: 3);
    final entries = await repo.loadAll();
    expect(entries, hasLength(1));
    expect(entries.first.newWords, 5);
  });

  test('currentStreak is 0 when today has no entry', () async {
    final repo = ProgressRepository();
    await repo.recordSession(date: '2026-09-20', newWords: 1);
    final streak = await repo.currentStreak(today: DateTime(2026, 9, 28));
    expect(streak, 0);
  });

  test('currentStreak counts consecutive days ending today', () async {
    final repo = ProgressRepository();
    await repo.recordSession(date: '2026-09-26', newWords: 1);
    await repo.recordSession(date: '2026-09-27', newWords: 1);
    await repo.recordSession(date: '2026-09-28', newWords: 1);
    final streak = await repo.currentStreak(today: DateTime(2026, 9, 28));
    expect(streak, 3);
  });

  test('currentStreak stops at a gap and does not overcount across it', () async {
    final repo = ProgressRepository();
    await repo.recordSession(date: '2026-09-24', newWords: 1); // gap here
    await repo.recordSession(date: '2026-09-27', newWords: 1);
    await repo.recordSession(date: '2026-09-28', newWords: 1);
    final streak = await repo.currentStreak(today: DateTime(2026, 9, 28));
    expect(streak, 2); // only the 27th and 28th, the 24th is across the gap
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/data/ -r expanded`
Expected: FAIL (repository files don't exist yet)

- [ ] **Step 4: Write `lib/data/profile_repository.dart`**

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';

class ProfileRepository {
  static const _key = 'profile';

  Future<Profile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return Profile.empty;
    return Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(Profile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
  }
}
```

- [ ] **Step 5: Write `lib/data/chat_repository.dart`**

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';

class ChatRepository {
  static const _key = 'chat_messages';

  Future<List<ChatMessage>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];
    return raw
        .map((s) => ChatMessage.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(ChatMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];
    await prefs.setStringList(_key, [...raw, jsonEncode(message.toJson())]);
  }
}
```

- [ ] **Step 6: Write `lib/data/progress_repository.dart`**

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/progress_entry.dart';

class ProgressRepository {
  static const _key = 'progress_daily';

  Future<List<ProgressEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];
    return raw
        .map((s) => ProgressEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> recordSession({
    required String date,
    int speakingTimeSeconds = 0,
    int challengesCompleted = 0,
    int newWords = 0,
  }) async {
    final entries = await loadAll();
    final index = entries.indexWhere((e) => e.date == date);
    if (index == -1) {
      entries.add(ProgressEntry(
        date: date,
        speakingTimeSeconds: speakingTimeSeconds,
        challengesCompleted: challengesCompleted,
        newWords: newWords,
      ));
    } else {
      final existing = entries[index];
      entries[index] = existing.copyWith(
        speakingTimeSeconds: existing.speakingTimeSeconds + speakingTimeSeconds,
        challengesCompleted: existing.challengesCompleted + challengesCompleted,
        newWords: existing.newWords + newWords,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      entries.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  /// Consecutive days of activity ending today (0 if today has no entry).
  Future<int> currentStreak({DateTime? today}) async {
    final entries = await loadAll();
    final byDate = {for (final e in entries) e.date: e};
    var cursor = _dateOnly(today ?? DateTime.now());
    var streak = 0;
    while (byDate.containsKey(_formatDate(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/data/ -r expanded`
Expected: PASS (9 tests)

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/data/profile_repository.dart \
        lib/data/chat_repository.dart lib/data/progress_repository.dart \
        test/data/profile_repository_test.dart test/data/chat_repository_test.dart \
        test/data/progress_repository_test.dart
git commit -m "flutter: shared_preferences repositories (profile, chat, progress)"
```

---

### Task 6: Seed models + fixtures + SeedRepository

**Files:**
- Create: `lib/models/buddy.dart`
- Create: `lib/models/community_group.dart`
- Create: `assets/seed/buddies.json`
- Create: `assets/seed/community.json`
- Create: `assets/seed/buddy_chat_demo.json`
- Create: `lib/data/seed_repository.dart`
- Modify: `pubspec.yaml` (register `assets/seed/`)
- Test: `test/data/seed_repository_test.dart`

**Interfaces:**
- Produces: `Buddy` (`id`, `name`, `level`, `city`, `interests`), `CommunityGroup` (`id`, `name`, `memberCount`, `description`), `SeedRepository` (`loadBuddies()`, `loadCommunityGroups()`, `loadBuddyChatDemo()`) — Task 11 (Find a Buddy/Buddy Chat) and Task 13 (Community) depend on these.

- [ ] **Step 1: Write the fixture JSON files**

```json
// assets/seed/buddies.json
[
  {"id": "kausar", "name": "Kausar", "level": "B1", "city": "Almaty", "interests": ["Movies", "Travel"]},
  {"id": "daniyar", "name": "Daniyar", "level": "A2", "city": "Astana", "interests": ["Sports", "Music"]},
  {"id": "aruzhan", "name": "Aruzhan", "level": "B1", "city": "Shymkent", "interests": ["Culture", "Cooking"]},
  {"id": "alan", "name": "Alan", "level": "B2", "city": "Karaganda", "interests": ["Technology", "Science"]},
  {"id": "malika", "name": "Malika", "level": "A2", "city": "Aktobe", "interests": ["Art", "Animals"]}
]
```

```json
// assets/seed/community.json
[
  {"id": "movies", "name": "Movies & TV Shows", "memberCount": 1200, "description": "Talk about your favourite films!"},
  {"id": "travel", "name": "Travel & Culture", "memberCount": 980, "description": "Share your experience and learn!"},
  {"id": "study-tips", "name": "Study Tips", "memberCount": 1500, "description": "Help each other and stay motivated!"},
  {"id": "games", "name": "Games & Hobbies", "memberCount": 670, "description": "Play, learn and make friends!"},
  {"id": "speaking-club", "name": "Speaking Club", "memberCount": 2000, "description": "Weekly voice chats and activities!"}
]
```

```json
// assets/seed/buddy_chat_demo.json
[
  {"sender": "buddy", "text": "Hi! How was your day?"},
  {"sender": "me", "text": "It was good! I went to the library today. What about you?"},
  {"sender": "buddy", "text": "Nice! I also studied for my test. Do you want to practice speaking later?"},
  {"sender": "me", "text": "Sure! Let's do a 10-minute call at 5?"},
  {"sender": "buddy", "text": "Perfect! See you then!"}
]
```

- [ ] **Step 2: Register the assets in `pubspec.yaml`**

Find the commented-out `assets:` block under `flutter:` in `pubspec.yaml` and replace it with:

```yaml
  assets:
    - assets/seed/
```

- [ ] **Step 3: Write the failing test**

```dart
// test/data/seed_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:study_budy/data/seed_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loadBuddies() parses all seeded buddies', () async {
    final buddies = await SeedRepository().loadBuddies();
    expect(buddies, hasLength(5));
    expect(buddies.first.name, 'Kausar');
    expect(buddies.first.interests, contains('Movies'));
  });

  test('loadCommunityGroups() parses all seeded groups', () async {
    final groups = await SeedRepository().loadCommunityGroups();
    expect(groups, hasLength(5));
    expect(groups.map((g) => g.id), contains('speaking-club'));
  });

  test('loadBuddyChatDemo() parses the seeded conversation', () async {
    final demo = await SeedRepository().loadBuddyChatDemo();
    expect(demo, isNotEmpty);
    expect(demo.first.sender, 'buddy');
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/data/seed_repository_test.dart -r expanded`
Expected: FAIL (`lib/data/seed_repository.dart` doesn't exist yet)

- [ ] **Step 5: Write `lib/models/buddy.dart`**

```dart
class Buddy {
  const Buddy({
    required this.id,
    required this.name,
    required this.level,
    required this.city,
    required this.interests,
  });

  final String id;
  final String name;
  final String level;
  final String city;
  final List<String> interests;

  factory Buddy.fromJson(Map<String, dynamic> json) => Buddy(
        id: json['id'] as String,
        name: json['name'] as String,
        level: json['level'] as String,
        city: json['city'] as String,
        interests: (json['interests'] as List).cast<String>(),
      );
}
```

- [ ] **Step 6: Write `lib/models/community_group.dart`**

```dart
class CommunityGroup {
  const CommunityGroup({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.description,
  });

  final String id;
  final String name;
  final int memberCount;
  final String description;

  factory CommunityGroup.fromJson(Map<String, dynamic> json) => CommunityGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        memberCount: json['memberCount'] as int,
        description: json['description'] as String,
      );
}
```

- [ ] **Step 7: Write `lib/data/seed_repository.dart`**

```dart
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/buddy.dart';
import '../models/community_group.dart';

class BuddyChatDemoMessage {
  const BuddyChatDemoMessage({required this.sender, required this.text});

  final String sender; // 'buddy' | 'me'
  final String text;

  factory BuddyChatDemoMessage.fromJson(Map<String, dynamic> json) =>
      BuddyChatDemoMessage(
        sender: json['sender'] as String,
        text: json['text'] as String,
      );
}

class SeedRepository {
  Future<List<Buddy>> loadBuddies() async {
    final raw = await rootBundle.loadString('assets/seed/buddies.json');
    return (jsonDecode(raw) as List)
        .map((e) => Buddy.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CommunityGroup>> loadCommunityGroups() async {
    final raw = await rootBundle.loadString('assets/seed/community.json');
    return (jsonDecode(raw) as List)
        .map((e) => CommunityGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BuddyChatDemoMessage>> loadBuddyChatDemo() async {
    final raw = await rootBundle.loadString('assets/seed/buddy_chat_demo.json');
    return (jsonDecode(raw) as List)
        .map((e) => BuddyChatDemoMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
```

- [ ] **Step 8: Run test to verify it passes**

Run: `flutter test test/data/seed_repository_test.dart -r expanded`
Expected: PASS (3 tests)

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml assets/seed/ lib/models/buddy.dart lib/models/community_group.dart \
        lib/data/seed_repository.dart test/data/seed_repository_test.dart
git commit -m "flutter: seed fixtures + SeedRepository (Find a Buddy / Community / Buddy Chat)"
```

---

### Task 7: BuddyChatApi (HTTP client to the backend)

**Files:**
- Add dependency: `http: ^1.6.0` to `pubspec.yaml`
- Create: `lib/data/buddy_chat_api.dart`
- Test: `test/data/buddy_chat_api_test.dart`

**Interfaces:**
- Consumes: `ChatMessage` (Task 4).
- Produces: `BuddyReply` (`reply`, `correction`, `explanation`), `BuddyChatException` (`message`), `BuddyChatApi` (`BuddyChatApi({required baseUrl, http.Client? client})`, `sendMessage({required history, required message, required level}) -> Future<BuddyReply>`) — Task 8 (`ChatProvider`) depends on this.

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add http`

- [ ] **Step 2: Write the failing tests**

```dart
// test/data/buddy_chat_api_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_budy/data/buddy_chat_api.dart';
import 'package:study_budy/models/chat_message.dart';

void main() {
  test('sendMessage returns a parsed BuddyReply on 200', () async {
    final mockClient = MockClient((request) async {
      expect(request.url.path, '/buddy/chat');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['message'], 'I go to school yesterday.');
      expect(body['level'], 'A2');
      return http.Response(
        jsonEncode({
          'reply': 'Nice!',
          'correction': 'I went to school yesterday.',
          'explanation': 'Past tense of go is went.',
        }),
        200,
      );
    });

    final api = BuddyChatApi(baseUrl: 'http://localhost:8000', client: mockClient);
    final reply = await api.sendMessage(
      history: const [],
      message: 'I go to school yesterday.',
      level: 'A2',
    );

    expect(reply.reply, 'Nice!');
    expect(reply.correction, 'I went to school yesterday.');
  });

  test('sendMessage throws BuddyChatException on 429', () async {
    final mockClient = MockClient((request) async => http.Response('', 429));
    final api = BuddyChatApi(baseUrl: 'http://localhost:8000', client: mockClient);

    expect(
      () => api.sendMessage(history: const [], message: 'Hi', level: 'B1'),
      throwsA(isA<BuddyChatException>()),
    );
  });

  test('sendMessage throws BuddyChatException when the server is unreachable', () async {
    final mockClient = MockClient((request) async => throw Exception('connection refused'));
    final api = BuddyChatApi(baseUrl: 'http://localhost:8000', client: mockClient);

    expect(
      () => api.sendMessage(history: const [], message: 'Hi', level: 'B1'),
      throwsA(isA<BuddyChatException>()),
    );
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/data/buddy_chat_api_test.dart -r expanded`
Expected: FAIL (`lib/data/buddy_chat_api.dart` doesn't exist yet)

- [ ] **Step 4: Write `lib/data/buddy_chat_api.dart`**

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';

class BuddyReply {
  const BuddyReply({required this.reply, this.correction, this.explanation});

  final String reply;
  final String? correction;
  final String? explanation;

  factory BuddyReply.fromJson(Map<String, dynamic> json) => BuddyReply(
        reply: json['reply'] as String,
        correction: json['correction'] as String?,
        explanation: json['explanation'] as String?,
      );
}

class BuddyChatException implements Exception {
  BuddyChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BuddyChatApi {
  BuddyChatApi({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<BuddyReply> sendMessage({
    required List<ChatMessage> history,
    required String message,
    required String level,
  }) async {
    final body = jsonEncode({
      'history': history
          .map((m) => {
                'role': m.sender == 'user' ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList(),
      'message': message,
      'level': level,
    });

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/buddy/chat'),
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw BuddyChatException("Can't reach your practice partner right now.");
    }

    if (response.statusCode == 429) {
      throw BuddyChatException('Daily practice limit reached, try again tomorrow.');
    }
    if (response.statusCode != 200) {
      throw BuddyChatException("Can't reach your practice partner right now.");
    }
    return BuddyReply.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/data/buddy_chat_api_test.dart -r expanded`
Expected: PASS (3 tests)

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/data/buddy_chat_api.dart test/data/buddy_chat_api_test.dart
git commit -m "flutter: BuddyChatApi HTTP client"
```

---

## Flutter — state layer

### Task 8: Providers (Profile, Progress, Chat)

**Files:**
- Create: `lib/state/profile_provider.dart`
- Create: `lib/state/progress_provider.dart`
- Create: `lib/state/chat_provider.dart`
- Test: `test/state/profile_provider_test.dart`
- Test: `test/state/progress_provider_test.dart`
- Test: `test/state/chat_provider_test.dart`

**Interfaces:**
- Consumes: `ProfileRepository`, `ChatRepository`, `ProgressRepository` (Task 5), `BuddyChatApi`/`BuddyReply`/`BuddyChatException` (Task 7), `ChatMessage`/`Profile` (Task 4).
- Produces: `ProfileProvider` (`profile`, `loaded`, `load()`, `completeOnboarding({name, level})`), `ProgressProvider` (`entries`, `streak`, `load()`, `recordSession({speakingTimeSeconds, challengesCompleted, newWords})`), `ChatProvider` (`messages`, `error`, `load()`, `sendMessage(String text)`) — all `ChangeNotifier`s consumed directly by screens in Tasks 9–15.

- [ ] **Step 1: Write the failing tests**

```dart
// test/state/profile_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/profile_repository.dart';
import 'package:study_budy/state/profile_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('completeOnboarding updates profile and persists it', () async {
    final provider = ProfileProvider(ProfileRepository());
    await provider.load();
    expect(provider.profile.onboardingComplete, false);

    await provider.completeOnboarding(name: 'Daryn', level: 'B1');
    expect(provider.profile.onboardingComplete, true);
    expect(provider.profile.name, 'Daryn');

    final reloaded = ProfileProvider(ProfileRepository());
    await reloaded.load();
    expect(reloaded.profile.name, 'Daryn');
  });
}
```

```dart
// test/state/progress_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/progress_repository.dart';
import 'package:study_budy/state/progress_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('recordSession updates entries and streak', () async {
    final provider = ProgressProvider(ProgressRepository());
    await provider.load();
    expect(provider.entries, isEmpty);

    await provider.recordSession(speakingTimeSeconds: 30, newWords: 1);
    expect(provider.entries, hasLength(1));
    expect(provider.streak, 1);
  });
}
```

```dart
// test/state/chat_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/buddy_chat_api.dart';
import 'package:study_budy/data/chat_repository.dart';
import 'package:study_budy/data/progress_repository.dart';
import 'package:study_budy/state/chat_provider.dart';
import 'package:study_budy/state/progress_provider.dart';

class _FailingApi extends BuddyChatApi {
  _FailingApi() : super(baseUrl: 'http://unused');

  @override
  Future<BuddyReply> sendMessage({
    required List history,
    required String message,
    required String level,
  }) {
    throw BuddyChatException("Can't reach your practice partner right now.");
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('sendMessage keeps the user message locally even if the API call fails', () async {
    final progressProvider = ProgressProvider(ProgressRepository());
    await progressProvider.load();

    final chatProvider = ChatProvider(
      repository: ChatRepository(),
      api: _FailingApi(),
      progressProvider: progressProvider,
      level: 'B1',
    );
    await chatProvider.load();

    await chatProvider.sendMessage('I go to school yesterday.');

    expect(chatProvider.messages, hasLength(1));
    expect(chatProvider.messages.first.text, 'I go to school yesterday.');
    expect(chatProvider.error, isNotNull);

    final persisted = await ChatRepository().loadAll();
    expect(persisted, hasLength(1));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/state/ -r expanded`
Expected: FAIL (provider files don't exist yet)

- [ ] **Step 3: Write `lib/state/profile_provider.dart`**

```dart
import 'package:flutter/foundation.dart';

import '../data/profile_repository.dart';
import '../models/profile.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider(this._repository);

  final ProfileRepository _repository;
  Profile _profile = Profile.empty;

  Profile get profile => _profile;

  Future<void> load() async {
    _profile = await _repository.load();
    notifyListeners();
  }

  Future<void> completeOnboarding({required String name, required String level}) async {
    _profile = Profile(name: name, level: level, onboardingComplete: true);
    await _repository.save(_profile);
    notifyListeners();
  }
}
```

- [ ] **Step 4: Write `lib/state/progress_provider.dart`**

```dart
import 'package:flutter/foundation.dart';

import '../data/progress_repository.dart';
import '../models/progress_entry.dart';

class ProgressProvider extends ChangeNotifier {
  ProgressProvider(this._repository);

  final ProgressRepository _repository;
  List<ProgressEntry> _entries = const [];
  int _streak = 0;

  List<ProgressEntry> get entries => _entries;
  int get streak => _streak;

  Future<void> load() async {
    _entries = await _repository.loadAll();
    _streak = await _repository.currentStreak();
    notifyListeners();
  }

  Future<void> recordSession({
    int speakingTimeSeconds = 0,
    int challengesCompleted = 0,
    int newWords = 0,
  }) async {
    await _repository.recordSession(
      date: _todayString(),
      speakingTimeSeconds: speakingTimeSeconds,
      challengesCompleted: challengesCompleted,
      newWords: newWords,
    );
    await load();
  }

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
```

- [ ] **Step 5: Write `lib/state/chat_provider.dart`**

```dart
import 'package:flutter/foundation.dart';

import '../data/buddy_chat_api.dart';
import '../data/chat_repository.dart';
import '../models/chat_message.dart';
import 'progress_provider.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required ChatRepository repository,
    required BuddyChatApi api,
    required ProgressProvider progressProvider,
    required String level,
  })  : _repository = repository,
        _api = api,
        _progressProvider = progressProvider,
        _level = level;

  final ChatRepository _repository;
  final BuddyChatApi _api;
  final ProgressProvider _progressProvider;
  final String _level;

  List<ChatMessage> _messages = const [];
  String? _error;

  List<ChatMessage> get messages => _messages;
  String? get error => _error;

  Future<void> load() async {
    _messages = await _repository.loadAll();
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    _error = null;
    final userMessage = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sender: 'user',
      text: text,
      createdAt: DateTime.now(),
    );
    // Persisted before the network call - never lost if it fails.
    await _repository.add(userMessage);
    _messages = [..._messages, userMessage];
    notifyListeners();

    try {
      final history = _messages.length > 1
          ? _messages.sublist(0, _messages.length - 1)
          : const <ChatMessage>[];
      final reply = await _api.sendMessage(history: history, message: text, level: _level);
      final aiMessage = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: 'ai',
        text: reply.reply,
        correction: reply.correction,
        explanation: reply.explanation,
        createdAt: DateTime.now(),
      );
      await _repository.add(aiMessage);
      _messages = [..._messages, aiMessage];
      await _progressProvider.recordSession(
        newWords: reply.correction != null ? 1 : 0,
        challengesCompleted: 0,
      );
    } on BuddyChatException catch (e) {
      _error = e.message;
    }
    notifyListeners();
  }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/state/ -r expanded`
Expected: PASS (3 tests)

- [ ] **Step 7: Commit**

```bash
git add lib/state/ test/state/
git commit -m "flutter: ChangeNotifier providers (profile, progress, chat)"
```

---

## Flutter — navigation shell

### Task 9: go_router shell (5-tab nav) + onboarding gate + main.dart wiring

**Files:**
- Add dependency: `go_router: ^18.0.1` to `pubspec.yaml`
- Create: `lib/router/app_router.dart`
- Create: `lib/screens/onboarding/onboarding_screen.dart`
- Modify: `lib/main.dart`
- Test: `test/router/onboarding_gate_test.dart`

**Interfaces:**
- Consumes: `ProfileProvider` (Task 8).
- Produces: `buildRouter(ProfileProvider)`, `AppShell` widget, route paths `/onboarding`, `/home`, `/community`, `/ai-buddy`, `/progress`, `/profile`, `/find-a-buddy`, `/buddy-chat/:buddyId` — every screen task (10–15) is registered against these paths, and `main.dart` is the file every later Flutter task's providers get wired into.

This task creates every screen file as a minimal-but-real placeholder `Scaffold` with just an `AppBar` title, since the router needs each route to resolve to *something* before Tasks 10–15 build out real content in those same files. That's normal incremental construction — each screen becomes fully real in its own later task, in the same file.

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add go_router`

- [ ] **Step 2: Create minimal screen files (filled out in later tasks)**

```dart
// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Home')));
}
```

```dart
// lib/screens/community/community_screen.dart
import 'package:flutter/material.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text('Community')));
}
```

```dart
// lib/screens/ai_buddy/ai_buddy_screen.dart
import 'package:flutter/material.dart';

class AiBuddyScreen extends StatelessWidget {
  const AiBuddyScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text('AI Buddy')));
}
```

```dart
// lib/screens/progress/progress_screen.dart
import 'package:flutter/material.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text('Progress')));
}
```

```dart
// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text('Profile')));
}
```

```dart
// lib/screens/find_a_buddy/find_a_buddy_screen.dart
import 'package:flutter/material.dart';

class FindABuddyScreen extends StatelessWidget {
  const FindABuddyScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text('Find a Buddy')));
}
```

```dart
// lib/screens/find_a_buddy/buddy_chat_screen.dart
import 'package:flutter/material.dart';

class BuddyChatScreen extends StatelessWidget {
  const BuddyChatScreen({required this.buddyId, super.key});

  final String buddyId;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text('Chat: $buddyId')));
}
```

- [ ] **Step 3: Write `lib/screens/onboarding/onboarding_screen.dart` (real, not a placeholder — this is this task's actual deliverable)**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/profile_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  String _level = 'A1';

  static const _levels = ['A1', 'A2', 'B1', 'B2'];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to Study Buddy')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('onboarding_name'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Your name'),
            ),
            const SizedBox(height: 16),
            DropdownButton<String>(
              key: const Key('onboarding_level'),
              value: _level,
              items: _levels
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (value) => setState(() => _level = value!),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('onboarding_submit'),
              onPressed: () {
                final name = _nameController.text.trim();
                if (name.isEmpty) return;
                context
                    .read<ProfileProvider>()
                    .completeOnboarding(name: name, level: _level);
              },
              child: const Text('Get Started'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Write `lib/router/app_router.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/ai_buddy/ai_buddy_screen.dart';
import '../screens/community/community_screen.dart';
import '../screens/find_a_buddy/buddy_chat_screen.dart';
import '../screens/find_a_buddy/find_a_buddy_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/progress/progress_screen.dart';
import '../state/profile_provider.dart';

const tabPaths = ['/home', '/community', '/ai-buddy', '/progress', '/profile'];
const tabLabels = ['Home', 'Community', 'AI Buddy', 'Progress', 'Profile'];
const tabIcons = [
  Icons.home,
  Icons.groups,
  Icons.smart_toy,
  Icons.trending_up,
  Icons.person,
];

GoRouter buildRouter(ProfileProvider profileProvider) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: profileProvider,
    redirect: (context, state) {
      final onboarded = profileProvider.profile.onboardingComplete;
      final onOnboarding = state.matchedLocation == '/onboarding';
      if (!onboarded && !onOnboarding) return '/onboarding';
      if (onboarded && onOnboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/community', builder: (_, __) => const CommunityScreen()),
          GoRoute(path: '/ai-buddy', builder: (_, __) => const AiBuddyScreen()),
          GoRoute(path: '/progress', builder: (_, __) => const ProgressScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(path: '/find-a-buddy', builder: (_, __) => const FindABuddyScreen()),
      GoRoute(
        path: '/buddy-chat/:buddyId',
        builder: (context, state) =>
            BuddyChatScreen(buddyId: state.pathParameters['buddyId']!),
      ),
    ],
  );
}

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = tabPaths.indexOf(location);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex < 0 ? 0 : currentIndex,
        onDestinationSelected: (index) => context.go(tabPaths[index]),
        destinations: [
          for (var i = 0; i < tabPaths.length; i++)
            NavigationDestination(icon: Icon(tabIcons[i]), label: tabLabels[i]),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Rewrite `lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/buddy_chat_api.dart';
import 'data/chat_repository.dart';
import 'data/profile_repository.dart';
import 'data/progress_repository.dart';
import 'router/app_router.dart';
import 'state/chat_provider.dart';
import 'state/profile_provider.dart';
import 'state/progress_provider.dart';

const backendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

void main() {
  runApp(const StudyBudyApp());
}

class StudyBudyApp extends StatelessWidget {
  const StudyBudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileProvider(ProfileRepository())..load()),
        ChangeNotifierProvider(create: (_) => ProgressProvider(ProgressRepository())..load()),
      ],
      child: Consumer2<ProfileProvider, ProgressProvider>(
        builder: (context, profileProvider, progressProvider, _) {
          return ChangeNotifierProvider(
            key: ValueKey(profileProvider.profile.level),
            create: (_) => ChatProvider(
              repository: ChatRepository(),
              api: BuddyChatApi(baseUrl: backendBaseUrl),
              progressProvider: progressProvider,
              level: profileProvider.profile.level,
            )..load(),
            child: Builder(
              builder: (context) {
                final router = buildRouter(profileProvider);
                return MaterialApp.router(
                  title: 'Study Buddy',
                  routerConfig: router,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 6: Write the failing test for the onboarding gate**

```dart
// test/router/onboarding_gate_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/profile_repository.dart';
import 'package:study_budy/router/app_router.dart';
import 'package:study_budy/state/profile_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('redirects to onboarding when profile is not onboarded', (tester) async {
    final profileProvider = ProfileProvider(ProfileRepository());
    await profileProvider.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: profileProvider,
        child: MaterialApp.router(routerConfig: buildRouter(profileProvider)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Study Buddy'), findsOneWidget);
  });

  testWidgets('shows Home once onboarding completes', (tester) async {
    final profileProvider = ProfileProvider(ProfileRepository());
    await profileProvider.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: profileProvider,
        child: MaterialApp.router(routerConfig: buildRouter(profileProvider)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('onboarding_name')), 'Daryn');
    await tester.tap(find.byKey(const Key('onboarding_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
  });
}
```

- [ ] **Step 7: Run test to verify it fails, then passes**

Run: `flutter test test/router/onboarding_gate_test.dart -r expanded`
Expected first: FAIL if any file above has a typo/import error — fix until it compiles, then it should PASS given Task 8's `ProfileProvider` already works.

- [ ] **Step 8: Run the whole test suite so far**

Run: `flutter analyze && flutter test`
Expected: `flutter analyze` reports no issues; all tests across every prior task still pass.

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart lib/router/ lib/screens/ test/router/
git commit -m "flutter: go_router shell, onboarding gate, 5-tab navigation"
```

---

## Flutter — screens

### Task 10: Home screen (streak + daily challenge)

**Files:**
- Create: `lib/data/challenges.dart`
- Modify: `lib/screens/home/home_screen.dart`
- Test: `test/screens/home_screen_test.dart`

**Interfaces:**
- Consumes: `ProgressProvider` (Task 8).
- Produces: `challengeForDate(DateTime) -> String` (used only here, but kept in its own file since it's pure logic worth testing independently).

- [ ] **Step 1: Write the failing tests**

```dart
// test/screens/home_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/challenges.dart';
import 'package:study_budy/data/progress_repository.dart';
import 'package:study_budy/screens/home/home_screen.dart';
import 'package:study_budy/state/progress_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('challengeForDate is stable for the same date', () {
    final date = DateTime(2026, 9, 28);
    expect(challengeForDate(date), challengeForDate(date));
  });

  testWidgets('renders streak and today\'s challenge', (tester) async {
    final progressProvider = ProgressProvider(ProgressRepository());
    await progressProvider.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: progressProvider,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('0-day streak'), findsOneWidget);
    expect(find.text(challengeForDate(DateTime.now())), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/home_screen_test.dart -r expanded`
Expected: FAIL (`lib/data/challenges.dart` doesn't exist; `HomeScreen` doesn't render a streak/challenge yet)

- [ ] **Step 3: Write `lib/data/challenges.dart`**

```dart
const List<String> dailyChallenges = [
  'Speak for 60 seconds about your weekend.',
  'Describe your favorite meal to a friend.',
  'Explain why you are learning English.',
  'Talk about a movie you watched recently.',
  'Describe your hometown to a visitor.',
  'Talk about your plans for next week.',
  'Explain how to make your favorite dish.',
];

String challengeForDate(DateTime date) {
  final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
  return dailyChallenges[dayOfYear % dailyChallenges.length];
}
```

- [ ] **Step 4: Rewrite `lib/screens/home/home_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/challenges.dart';
import '../../state/progress_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${progress.streak}-day streak',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text("Today's Challenge", style: Theme.of(context).textTheme.titleMedium),
          Text(challengeForDate(DateTime.now())),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/find-a-buddy'),
            child: const Text('Find a Buddy'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/screens/home_screen_test.dart -r expanded`
Expected: PASS (2 tests)

- [ ] **Step 6: Commit**

```bash
git add lib/data/challenges.dart lib/screens/home/home_screen.dart test/screens/home_screen_test.dart
git commit -m "flutter: Home screen (streak + daily challenge)"
```

---

### Task 11: Find a Buddy + Buddy Chat screens (mocked)

**Files:**
- Modify: `lib/screens/find_a_buddy/find_a_buddy_screen.dart`
- Modify: `lib/screens/find_a_buddy/buddy_chat_screen.dart`
- Test: `test/screens/find_a_buddy_screen_test.dart`
- Test: `test/screens/buddy_chat_screen_test.dart`

**Interfaces:**
- Consumes: `SeedRepository`, `Buddy`, `BuddyChatDemoMessage` (Task 6).

- [ ] **Step 1: Write the failing tests**

```dart
// test/screens/find_a_buddy_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_budy/screens/find_a_buddy/find_a_buddy_screen.dart';

void main() {
  testWidgets('renders every seeded buddy by name', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FindABuddyScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Kausar'), findsOneWidget);
    expect(find.text('Daniyar'), findsOneWidget);
    expect(find.text('Malika'), findsOneWidget);
  });

  testWidgets('tapping Connect shows a stub message, not an error', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FindABuddyScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('connect_kausar')));
    await tester.pump();

    expect(find.textContaining('Connect'), findsWidgets);
  });
}
```

```dart
// test/screens/buddy_chat_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_budy/screens/find_a_buddy/buddy_chat_screen.dart';

void main() {
  testWidgets('renders the seeded demo conversation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: BuddyChatScreen(buddyId: 'kausar')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('How was your day?'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/find_a_buddy_screen_test.dart test/screens/buddy_chat_screen_test.dart -r expanded`
Expected: FAIL (screens still show only an `AppBar` title from Task 9)

- [ ] **Step 3: Rewrite `lib/screens/find_a_buddy/find_a_buddy_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/seed_repository.dart';
import '../../models/buddy.dart';

class FindABuddyScreen extends StatefulWidget {
  const FindABuddyScreen({super.key});

  @override
  State<FindABuddyScreen> createState() => _FindABuddyScreenState();
}

class _FindABuddyScreenState extends State<FindABuddyScreen> {
  late Future<List<Buddy>> _buddies;

  @override
  void initState() {
    super.initState();
    _buddies = SeedRepository().loadBuddies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find a Buddy')),
      body: FutureBuilder<List<Buddy>>(
        future: _buddies,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final buddies = snapshot.data!;
          return ListView.builder(
            itemCount: buddies.length,
            itemBuilder: (context, index) {
              final buddy = buddies[index];
              return ListTile(
                title: Text(buddy.name),
                subtitle: Text('${buddy.level} · ${buddy.city}'),
                onTap: () => context.go('/buddy-chat/${buddy.id}'),
                trailing: TextButton(
                  key: Key('connect_${buddy.id}'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Connect request sent to ${buddy.name}!')),
                    );
                  },
                  child: const Text('Connect'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Rewrite `lib/screens/find_a_buddy/buddy_chat_screen.dart`**

```dart
import 'package:flutter/material.dart';

import '../../data/seed_repository.dart';

class BuddyChatScreen extends StatefulWidget {
  const BuddyChatScreen({required this.buddyId, super.key});

  final String buddyId;

  @override
  State<BuddyChatScreen> createState() => _BuddyChatScreenState();
}

class _BuddyChatScreenState extends State<BuddyChatScreen> {
  late Future<List<BuddyChatDemoMessage>> _demo;

  @override
  void initState() {
    super.initState();
    _demo = SeedRepository().loadBuddyChatDemo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat: ${widget.buddyId}')),
      body: FutureBuilder<List<BuddyChatDemoMessage>>(
        future: _demo,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final messages = snapshot.data!;
          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final isMe = message.sender == 'me';
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.blue.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(message.text),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/screens/find_a_buddy_screen_test.dart test/screens/buddy_chat_screen_test.dart -r expanded`
Expected: PASS (3 tests)

- [ ] **Step 6: Commit**

```bash
git add lib/screens/find_a_buddy/ test/screens/find_a_buddy_screen_test.dart test/screens/buddy_chat_screen_test.dart
git commit -m "flutter: Find a Buddy + Buddy Chat screens (seeded, mocked)"
```

---

### Task 12: AI Buddy screen (real chat + inline correction card + degraded state)

**Files:**
- Modify: `lib/screens/ai_buddy/ai_buddy_screen.dart`
- Test: `test/screens/ai_buddy_screen_test.dart`

**Interfaces:**
- Consumes: `ChatProvider` (Task 8), `ChatMessage` (Task 4).

- [ ] **Step 1: Write the failing tests**

```dart
// test/screens/ai_buddy_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/buddy_chat_api.dart';
import 'package:study_budy/data/chat_repository.dart';
import 'package:study_budy/data/progress_repository.dart';
import 'package:study_budy/screens/ai_buddy/ai_buddy_screen.dart';
import 'package:study_budy/state/chat_provider.dart';
import 'package:study_budy/state/progress_provider.dart';

class _ScriptedApi extends BuddyChatApi {
  _ScriptedApi(this._reply) : super(baseUrl: 'http://unused');
  final BuddyReply _reply;

  @override
  Future<BuddyReply> sendMessage({
    required List history,
    required String message,
    required String level,
  }) async =>
      _reply;
}

class _FailingApi extends BuddyChatApi {
  _FailingApi() : super(baseUrl: 'http://unused');

  @override
  Future<BuddyReply> sendMessage({
    required List history,
    required String message,
    required String level,
  }) {
    throw BuddyChatException("Can't reach your practice partner right now.");
  }
}

Future<ChatProvider> _pumpAiBuddy(WidgetTester tester, BuddyChatApi api) async {
  SharedPreferences.setMockInitialValues({});
  final progressProvider = ProgressProvider(ProgressRepository());
  await progressProvider.load();
  final chatProvider = ChatProvider(
    repository: ChatRepository(),
    api: api,
    progressProvider: progressProvider,
    level: 'B1',
  );
  await chatProvider.load();

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: chatProvider,
      child: const MaterialApp(home: AiBuddyScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return chatProvider;
}

void main() {
  testWidgets('sending a message shows the reply and the correction card', (tester) async {
    await _pumpAiBuddy(
      tester,
      _ScriptedApi(const BuddyReply(
        reply: 'Nice!',
        correction: 'I went to school yesterday.',
        explanation: 'Past tense of go is went.',
      )),
    );

    await tester.enterText(find.byKey(const Key('ai_buddy_input')), 'I go to school yesterday.');
    await tester.tap(find.byKey(const Key('ai_buddy_send')));
    await tester.pumpAndSettle();

    expect(find.text('Nice!'), findsOneWidget);
    expect(find.byKey(const Key('ai_feedback_card')), findsOneWidget);
    expect(find.textContaining('I went to school yesterday.'), findsOneWidget);
  });

  testWidgets('a failed backend call shows an inline error, not a crash', (tester) async {
    await _pumpAiBuddy(tester, _FailingApi());

    await tester.enterText(find.byKey(const Key('ai_buddy_input')), 'Hi');
    await tester.tap(find.byKey(const Key('ai_buddy_send')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai_buddy_error')), findsOneWidget);
    expect(find.text('Hi'), findsOneWidget); // the user's message is still shown
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/ai_buddy_screen_test.dart -r expanded`
Expected: FAIL (`AiBuddyScreen` doesn't have an input/send/message list yet)

- [ ] **Step 3: Rewrite `lib/screens/ai_buddy/ai_buddy_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_message.dart';
import '../../state/chat_provider.dart';

class AiBuddyScreen extends StatefulWidget {
  const AiBuddyScreen({super.key});

  @override
  State<AiBuddyScreen> createState() => _AiBuddyScreenState();
}

class _AiBuddyScreenState extends State<AiBuddyScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('AI Buddy')),
      body: Column(
        children: [
          if (chat.error != null)
            Container(
              key: const Key('ai_buddy_error'),
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Text(chat.error!),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: chat.messages.length,
              itemBuilder: (context, index) => _MessageBubble(message: chat.messages[index]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(key: const Key('ai_buddy_input'), controller: _controller),
                ),
                IconButton(
                  key: const Key('ai_buddy_send'),
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    final text = _controller.text.trim();
                    if (text.isEmpty) return;
                    _controller.clear();
                    context.read<ChatProvider>().sendMessage(text);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUser ? Colors.blue.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(message.text),
          ),
          if (message.correction != null)
            Container(
              key: const Key('ai_feedback_card'),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Correction: ${message.correction}'),
                  if (message.explanation != null) Text(message.explanation!),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/ai_buddy_screen_test.dart -r expanded`
Expected: PASS (2 tests) — the second test is this plan's Review Focus item for "backend unreachable degrades only this tab": Home (Task 10), Find a Buddy/Buddy Chat (Task 11), Community (Task 13), and Progress (Task 14) never construct a `BuddyChatApi` at all, so they're unaffected by this failure mode by construction, not by a separate test.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/ai_buddy/ test/screens/ai_buddy_screen_test.dart
git commit -m "flutter: AI Buddy screen (chat + inline correction card + error state)"
```

---

### Task 13: Community screen

**Files:**
- Modify: `lib/screens/community/community_screen.dart`
- Test: `test/screens/community_screen_test.dart`

**Interfaces:**
- Consumes: `SeedRepository`, `CommunityGroup` (Task 6).

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/community_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_budy/screens/community/community_screen.dart';

void main() {
  testWidgets('renders every seeded community group', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CommunityScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Movies & TV Shows'), findsOneWidget);
    expect(find.text('Speaking Club'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/community_screen_test.dart -r expanded`
Expected: FAIL (screen still shows only the Task 9 `AppBar` placeholder)

- [ ] **Step 3: Rewrite `lib/screens/community/community_screen.dart`**

```dart
import 'package:flutter/material.dart';

import '../../data/seed_repository.dart';
import '../../models/community_group.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late Future<List<CommunityGroup>> _groups;

  @override
  void initState() {
    super.initState();
    _groups = SeedRepository().loadCommunityGroups();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      body: FutureBuilder<List<CommunityGroup>>(
        future: _groups,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final groups = snapshot.data!;
          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                title: Text(group.name),
                subtitle: Text('${group.memberCount} members · ${group.description}'),
              );
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/community_screen_test.dart -r expanded`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/community/community_screen.dart test/screens/community_screen_test.dart
git commit -m "flutter: Community screen (seeded groups)"
```

---

### Task 14: Progress screen

**Files:**
- Modify: `lib/screens/progress/progress_screen.dart`
- Test: `test/screens/progress_screen_test.dart`

**Interfaces:**
- Consumes: `ProgressProvider` (Task 8).

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/progress_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/progress_repository.dart';
import 'package:study_budy/screens/progress/progress_screen.dart';
import 'package:study_budy/state/progress_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders streak and recorded sessions', (tester) async {
    final provider = ProgressProvider(ProgressRepository());
    await provider.load();
    await provider.recordSession(speakingTimeSeconds: 90, newWords: 4, challengesCompleted: 1);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: ProgressScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1-day streak'), findsOneWidget);
    expect(find.textContaining('4'), findsWidgets); // new words shown somewhere
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/progress_screen_test.dart -r expanded`
Expected: FAIL

- [ ] **Step 3: Rewrite `lib/screens/progress/progress_screen.dart`**

A simple list view of today's totals is enough for this MVP — no charting package, that would be an unrequested dependency for a single-user demo.

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/progress_provider.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    final totalWords = progress.entries.fold<int>(0, (sum, e) => sum + e.newWords);
    final totalChallenges =
        progress.entries.fold<int>(0, (sum, e) => sum + e.challengesCompleted);
    final totalSeconds =
        progress.entries.fold<int>(0, (sum, e) => sum + e.speakingTimeSeconds);

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${progress.streak}-day streak', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          ListTile(title: const Text('Speaking time'), trailing: Text('${totalSeconds}s')),
          ListTile(title: const Text('Challenges completed'), trailing: Text('$totalChallenges')),
          ListTile(title: const Text('New words'), trailing: Text('$totalWords')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/progress_screen_test.dart -r expanded`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/progress/progress_screen.dart test/screens/progress_screen_test.dart
git commit -m "flutter: Progress screen (streak + totals)"
```

---

### Task 15: Profile screen

**Files:**
- Modify: `lib/screens/profile/profile_screen.dart`
- Test: `test/screens/profile_screen_test.dart`

**Interfaces:**
- Consumes: `ProfileProvider` (Task 8).

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/profile_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/profile_repository.dart';
import 'package:study_budy/screens/profile/profile_screen.dart';
import 'package:study_budy/state/profile_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders the profile name and level', (tester) async {
    final provider = ProfileProvider(ProfileRepository());
    await provider.load();
    await provider.completeOnboarding(name: 'Daryn', level: 'B1');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daryn'), findsOneWidget);
    expect(find.textContaining('B1'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/profile_screen_test.dart -r expanded`
Expected: FAIL

- [ ] **Step 3: Rewrite `lib/screens/profile/profile_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/profile_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(profile.name, style: Theme.of(context).textTheme.headlineSmall),
            Text('Level: ${profile.level}'),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/profile_screen_test.dart -r expanded`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/profile/profile_screen.dart test/screens/profile_screen_test.dart
git commit -m "flutter: Profile screen"
```

---

## Final integration

### Task 16: Full verification pass + README + delete the stale template test

**Files:**
- Delete: `test/widget_test.dart` (the `flutter create` template's counter-app test — no longer matches `lib/main.dart`)
- Modify: `README.md`

**Interfaces:**
- Consumes: everything from Tasks 1–15.

- [ ] **Step 1: Delete the stale template test**

```bash
rm test/widget_test.dart
```

(It tests a counter app that `lib/main.dart` no longer builds — every real screen already has its own test from Tasks 9–15.)

- [ ] **Step 2: Run the full Flutter suite**

Run: `flutter analyze && flutter test`
Expected: `flutter analyze` — no issues found. `flutter test` — every test from Tasks 4–15 passes, nothing skipped.

- [ ] **Step 3: Run the full backend suite**

Run: `cd server && uv run pytest -v`
Expected: every test from Tasks 1–3 passes.

- [ ] **Step 4: Manual end-to-end pass**

```bash
cd server && uv run uvicorn app.main:app --reload --port 8000   # keep running
```

In another terminal:

```bash
cd /Users/baubek/Desktop/GITHUB/Daryn-Projects/study-budy
flutter run -d chrome --dart-define=BACKEND_BASE_URL=http://localhost:8000
```

Walk through: onboarding (enter a name, pick a level) → Home (streak shows `0-day streak`, a challenge line is visible) → tap "Find a Buddy" (all 5 seeded buddies render) → tap one (seeded conversation renders) → back, go to AI Buddy tab, send a grammatically wrong sentence (e.g. "I go to school yesterday.") → confirm a reply with a correction card appears → go to Progress tab → confirm streak is now `1-day streak` and "New words" is non-zero.

Then stop the `uvicorn` process (Ctrl-C) and, with the app still running, send another message in AI Buddy: confirm the inline error banner appears and the app doesn't crash, while switching to Home/Community/Progress still works normally.

- [ ] **Step 5: Update `README.md`**

Replace the current "Getting started" section with:

```markdown
## Getting started

### Backend (required for AI Buddy)

```sh
cd server
cp .env.example .env   # then fill in your real OPENROUTER_API_KEY
uv run uvicorn app.main:app --reload --port 8000
```

### App

```sh
flutter pub get
flutter run -d chrome --dart-define=BACKEND_BASE_URL=http://localhost:8000   # web
flutter run --dart-define=BACKEND_BASE_URL=http://localhost:8000            # any connected/simulated device
```

Every screen except AI Buddy works fully offline (seeded/local data). AI Buddy needs the backend above running.

## Checks

```sh
flutter analyze
flutter test
cd server && uv run pytest
```
```

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "flutter+server: final integration pass, README, drop stale template test"
```
