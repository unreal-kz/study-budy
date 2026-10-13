from typing import Literal

from pydantic import BaseModel, Field


class HistoryMessage(BaseModel):
    role: str  # "user" | "assistant"
    content: str


class ChatRequest(BaseModel):
    history: list[HistoryMessage]
    message: str
    level: str  # "A1" | "A2" | "B1" | "B2"
    # Optional hints from the v2 client. Absent for the prod client on main, in
    # which case the prompt is exactly what it was before modes existed.
    mode: Literal["free", "topic", "ielts"] | None = None
    topic: str | None = Field(default=None, max_length=300)


class BuddyReply(BaseModel):
    reply: str
    correction: str | None = None
    explanation: str | None = None
