# Study Buddy — MVP Design

## Context

Study Buddy is a Flutter mobile app (Android, iOS, Web) for practicing spoken
English, built as a learning/pet project for Daryn (Baubek's brother), whose
concept is captured in `docs/concept/`. Success is defined as **a working
app**, not a scaled product: this is a demo built around one live account,
not a multi-user launch.

Concept features (from the mockups): onboarding, Home (streak + daily
challenge), Find a Buddy (matching), Buddy Chat (text/voice/call), AI Buddy
(voice chat with grammar feedback), Community (topic groups), Progress
(speaking time, confidence score, words learned).

## Scope decisions (confirmed with Baubek)

- **Goal:** pet/learning project. Working app matters more than scale or a
  real user base.
- **Demo shape:** one live account. Find a Buddy, Buddy Chat, and Community
  are seeded/mocked — no real second user is required for the app to "work."
  AI Buddy is the one subsystem that must be genuinely live, because it's
  the only feature that doesn't need a second human.
- **AI Buddy v1 is text-only.** Voice (STT/TTS) is committed for a later
  phase, not this one — confirmed explicitly, not optional.
- **No paid APIs.** Budget is $0. Confirmed after evaluating options (see
  Model choice below).

### In scope (this design / first implementation plan)

- Onboarding + local profile (user self-selects their English level, A1–B2,
  during onboarding — no assessment logic)
- Home: streak, daily challenge (local logic, no backend)
- Find a Buddy: browse seeded profiles; "Connect" is a stub (toast/no-op)
- Buddy Chat: seeded, static conversation (mocked, not a real second user)
- **AI Buddy: real text chat + structured grammar feedback**, via a thin
  backend proxy to OpenRouter
- Community: browse seeded groups/posts
- Progress: real data, computed from actual AI Buddy usage

### Out of scope (explicitly deferred, not part of this plan)

- Voice input/output for AI Buddy
- Real multi-user backend: auth, real matching, real inter-user chat, real
  community posting
- Public deployment of the backend (runs locally via `uvicorn` during
  development; hosting decided before a demo that doesn't require Baubek's
  Mac to be reachable)
- Push notifications, monetization, analytics, CI/CD

Local storage design is **independent of future scale**: it's per-device,
per-user data regardless of how many total users the app ever has. What
would actually need rebuilding if this "took off" is the mocked subsystems
above (Find a Buddy / Buddy Chat / Community) — a real multi-user backend
with auth and shared state. That rebuild, if it ever happens, is separate
future work, not something this design needs to hedge against now.

## Architecture

Monorepo, single GitHub repo (`unreal-kz/study-budy`, created after this
spec is approved and initial code exists):

```
study-budy/
├── lib/                  # Flutter app
├── server/               # FastAPI backend (Python, uv) — thin proxy only
│   ├── app/
│   │   └── main.py       # POST /buddy/chat
│   ├── pyproject.toml
│   └── .env              # OPENROUTER_API_KEY (gitignored)
├── docs/
│   ├── concept/          # raw concept material (already present)
│   └── superpowers/specs/
└── android/ ios/ web/    # already scaffolded
```

The Flutter app is the only client. The FastAPI backend is the only holder
of `OPENROUTER_API_KEY` and the only thing that talks to OpenRouter — the
key never ships inside the compiled app or touches git. Backend runs
locally (`uvicorn`) during development; a public host (Fly.io / Render free
tier) is chosen later, before Daryn needs to use the app without Baubek's
Mac being on and reachable.

Find a Buddy and Community are **read-only JSON fixtures** bundled as
Flutter assets (`assets/seed/buddies.json`, `assets/seed/community.json`),
loaded into memory at startup — no backend involvement.

## Model choice: `google/gemma-4-31b-it:free` via OpenRouter

Evaluated against the $0 budget constraint (confirmed live via OpenRouter's
public models API, `https://openrouter.ai/api/v1/models`, and OpenRouter's
own rate-limit docs, both fetched 2026-09-28 — not from secondhand sources):

- `google/gemma-4-31b-it:free` — 31B dense, 256K context, `$0`/`$0`,
  supports `response_format` and `tools` per its OpenRouter model metadata.
- Free-tier rate limits (OpenRouter docs): 20 req/min always; 50 req/day at
  $0 lifetime spend (we're staying at $0, so 50/day is the real ceiling) —
  ample for a single demo account.
- Risk, stated plainly: free models "may be removed or have limits adjusted
  without notice" (OpenRouter's own wording). Acceptable for a pet project;
  revisit if it happens.
- Structured-output reliability is **not guaranteed the way Anthropic's
  `output_config.format` is** — open-weight models via OpenRouter are less
  consistent at strict JSON adherence. The backend must validate and
  gracefully degrade (see Error handling), not assume clean JSON always
  arrives.

Alternative considered: Google AI Studio direct (Gemini Flash / Gemma, also
free). Rejected for this project because free-tier rate limits are no
longer published (per-project only, checked in the AI Studio console) and
Google's own free-tier terms allow using request data to improve their
products — OpenRouter's limits are transparent and documented.

## Data model (local storage)

**Package: `shared_preferences`.** Chosen over `sqflite` after checking
platform support directly (pub.dev, 2026-09-28): `sqflite` has no native Web
support — Web needs the separately-experimental `sqflite_common_ffi_web`,
and Web is one of our three required platforms. `shared_preferences`
officially supports Android/iOS/Web/macOS/Windows/Linux with no
experimental flag. At our data volume (one user, low hundreds of records at
most), a full SQL engine adds nothing — records are stored as
JSON-serialized lists behind small repository classes.

Data held (evolving, written by the app):

- `profile` — single record: name, English level (A1–B2), avatar,
  onboarding_complete
- `chat_messages` — list of `{id, sender: user|ai, text, correction,
  explanation, created_at}` — the AI Buddy conversation history
- `progress_daily` — list of `{date, speaking_time_seconds,
  challenges_completed, new_words}` — actual usage

Streak and the "Speaking Confidence" graph are **derived from
`progress_daily`** at read time, not stored as separate fields — avoids
sync bugs between a stored counter and the underlying activity log.

Fixture data (read-only, bundled as assets, not in the data model above):
`buddies.json`, `community.json`.

## AI Buddy conversation flow

1. User types a message → written to local `chat_messages` immediately
   (optimistic; survives a failed network call).
2. Flutter sends `POST /buddy/chat` to the backend with the last N messages
   of history.
3. Backend builds a system prompt (English-practice partner for a
   Kazakhstani student at the user's level; reply conversationally, and
   when the message has a grammar mistake, also produce a correction +
   explanation) and calls OpenRouter
   (`google/gemma-4-31b-it:free`, `response_format: json_schema`) for:

   ```json
   {"reply": "...", "correction": "... | null", "explanation": "... | null"}
   ```

4. Backend parses/validates the JSON, returns it to Flutter, which appends
   it to `chat_messages` and updates today's `progress_daily` row.

## Error handling

- **Network/timeout talking to the backend:** the user's message is already
  safe in local storage; UI shows inline retry, nothing is lost.
- **OpenRouter rate limit (429):** backend catches it and returns a
  friendly, specific message ("daily practice limit reached, try again
  tomorrow") — not a raw HTTP error surfaced to the user.
- **Malformed/non-schema-conforming JSON from Gemma:** backend validates
  before returning; on failure, retries once, then falls back to a
  plain-text `reply` with `correction: null` rather than crashing the
  request. This path gets an explicit unit test (see Testing).
- **Backend unreachable at all** (e.g., not running locally): only the
  **AI Buddy** tab is affected — it shows a "can't reach your practice
  partner right now" state. Home, Community, Progress, and Find a Buddy are
  fully local/mocked and keep working regardless.

## Screens, navigation, state management

Bottom navigation — 5 tabs, matching the mockups: **Home · Community · AI
Buddy · Progress · Profile**. Find a Buddy and Buddy Chat are pushed routes
reached from Home/Community, not their own tabs.

```
lib/
├── main.dart
├── data/          # repositories: profile, progress, chat, seed loaders
├── screens/
│   ├── onboarding/
│   ├── home/
│   ├── find_a_buddy/   # + buddy_chat/ (mocked)
│   ├── ai_buddy/        # chat + inline AI Feedback card
│   ├── community/
│   └── progress/
└── widgets/
```

- **Routing:** `go_router` — declarative, first-party, handles a
  bottom-nav-with-per-tab-stack layout (our exact shape) out of the box.
- **State management:** `provider` (`ChangeNotifier` + `Provider`/
  `Consumer`). Chosen over Riverpod/Bloc for this scope — a handful of
  repository objects (profile, progress, chat) don't need more ceremony,
  and `provider` is the most widely-documented pattern, which matters since
  this is partly a learning project for Daryn too.

## Testing

- **Flutter:** unit tests on the repository layer (JSON
  serialize/deserialize round-trip for `shared_preferences` — the only
  logic with real failure modes); widget tests on key screens, replacing
  the placeholder `widget_test.dart`.
- **Backend (pytest):** tests for `/buddy/chat` with the OpenRouter call
  mocked (never hit the real API in tests — it would burn the 50/day free
  budget); an explicit test for the malformed-JSON fallback path, since
  that's the highest-risk piece of this design.
- **CI:** not required for this MVP; a `.github/workflows` running
  `flutter analyze` / `flutter test` / `pytest` is reasonable future
  polish, not a blocker.

## Verification (end-to-end, for the implementation plan)

- `flutter analyze` / `flutter test` clean
- `pytest` clean in `server/`, including the fallback-path test
- Manual: onboarding → Home → Find a Buddy (seed data renders) → AI Buddy
  (real round trip against the local `uvicorn` server, a grammatically
  wrong sentence produces a correction) → Progress (reflects the session
  just had)
- Manual: stop the backend, confirm only the AI Buddy tab degrades
  gracefully, everything else still works
