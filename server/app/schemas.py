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
