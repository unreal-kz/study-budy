"""Provider-neutral errors raised by the LLM clients and mapped to HTTP in main.py."""


class LLMError(Exception):
    """Raised when the LLM provider can't be reached or returns an error status."""


class RateLimitedError(LLMError):
    """Raised when the LLM provider signals a rate limit (HTTP 429)."""
