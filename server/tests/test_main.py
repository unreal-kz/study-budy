# server/tests/test_main.py
import importlib
import os

import pytest

import app.main as main_module
from app.main import validate_app_token_config

# The exact location `find_dotenv()` resolves to when called from
# app/main.py: python-dotenv walks up from the calling source file's
# directory (server/app/), landing on server/.env - the file the README
# tells developers to create via `cp .env.example .env`.
_ENV_PATH = os.path.abspath(
    os.path.join(os.path.dirname(main_module.__file__), os.pardir, ".env")
)


def test_main_actually_loads_env_file_on_import(monkeypatch):
    """Regression test for: `uv run uvicorn app.main:app` never loaded
    server/.env because nothing called load_dotenv().

    Writes a real server/.env with a known key, reloads app.main (re-running
    its module-level code, including the load_dotenv() call this fix adds),
    and asserts the key from that real file lands in os.environ. Fails
    before the fix (nothing loads the file) and passes after.
    """
    monkeypatch.delenv("STUDY_BUDDY_DOTENV_PROBE", raising=False)
    existed = os.path.exists(_ENV_PATH)
    original_content = None
    if existed:
        with open(_ENV_PATH, encoding="utf-8") as f:
            original_content = f.read()

    try:
        with open(_ENV_PATH, "w", encoding="utf-8") as f:
            f.write("STUDY_BUDDY_DOTENV_PROBE=loaded-from-dotenv\n")

        importlib.reload(main_module)

        assert os.environ.get("STUDY_BUDDY_DOTENV_PROBE") == "loaded-from-dotenv"
    finally:
        if existed:
            with open(_ENV_PATH, "w", encoding="utf-8") as f:
                f.write(original_content)
        else:
            os.remove(_ENV_PATH)
        os.environ.pop("STUDY_BUDDY_DOTENV_PROBE", None)
        importlib.reload(main_module)


# --- validate_app_token_config: ST-37 fail-closed guard -------------------
#
# REQUIRE_APP_TOKEN is an opt-in flag (set in render.yaml for the Render
# deployment) that turns a missing/blank APP_TOKEN from a silently-open
# endpoint (today's local-dev default) into a startup crash, so an env-var
# edit that blanks APP_TOKEN in prod fails the deploy instead of reopening
# /buddy/chat with no auth.


@pytest.mark.parametrize("flag", ["1", "true", "True", "YES", "on"])
def test_validate_app_token_config_raises_when_token_missing(flag):
    with pytest.raises(RuntimeError, match="APP_TOKEN"):
        validate_app_token_config({"REQUIRE_APP_TOKEN": flag})


@pytest.mark.parametrize("token", ["", "   "])
def test_validate_app_token_config_raises_when_token_blank(token):
    with pytest.raises(RuntimeError, match="APP_TOKEN"):
        validate_app_token_config({"REQUIRE_APP_TOKEN": "1", "APP_TOKEN": token})


def test_validate_app_token_config_passes_when_token_set():
    validate_app_token_config({"REQUIRE_APP_TOKEN": "1", "APP_TOKEN": "real-token"})


@pytest.mark.parametrize("flag", [None, "0", "false", "False", "no", "off", ""])
def test_validate_app_token_config_flag_unset_or_falsy_is_fail_open(flag):
    env = {} if flag is None else {"REQUIRE_APP_TOKEN": flag}
    # No APP_TOKEN either - must not raise, matching today's local-dev default.
    validate_app_token_config(env)


def test_validate_app_token_config_rejects_unrecognised_flag_value():
    # A typo (e.g. "ture" for "true") must not silently fall back to
    # fail-open - reject anything that isn't a recognised truthy/falsy token.
    with pytest.raises(ValueError, match="REQUIRE_APP_TOKEN"):
        validate_app_token_config({"REQUIRE_APP_TOKEN": "ture"})


def test_validate_app_token_config_runs_at_import_and_crashes_process(monkeypatch):
    """End-to-end: importing app.main with the flag set and no token raises,
    the same way it would if uvicorn tried to start the app in that state.
    """
    monkeypatch.setenv("REQUIRE_APP_TOKEN", "1")
    monkeypatch.delenv("APP_TOKEN", raising=False)
    try:
        with pytest.raises(RuntimeError, match="APP_TOKEN"):
            importlib.reload(main_module)
    finally:
        monkeypatch.delenv("REQUIRE_APP_TOKEN", raising=False)
        importlib.reload(main_module)
