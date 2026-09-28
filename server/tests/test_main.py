# server/tests/test_main.py
import importlib
import os

import app.main as main_module

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
