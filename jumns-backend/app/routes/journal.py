"""CRUD routes for /api/journal — Echo's journal entries."""

from fastapi import APIRouter, Request, Response

from app.db.repositories.journal import JournalRepository
from app.models.requests import CreateJournalEntryRequest, UpdateJournalEntryRequest
from app.models.responses import JournalEntryResponse

router = APIRouter(prefix="/journal", tags=["journal"])


def _to_response(item: dict) -> JournalEntryResponse:
    return JournalEntryResponse(
        id=item.get("id", ""),
        user_id=item["userId"],
        type=item.get("type", "thought"),
        title=item.get("title", ""),
        content=item.get("content", ""),
        mood=item.get("mood"),
        tags=item.get("tags", []),
        shareable=item.get("shareable", False),
        draft=item.get("draft", True),
        agent_prompted=item.get("agentPrompted", False),
        linked_goal_id=item.get("linkedGoalId"),
        media_url=item.get("mediaUrl"),
        created_at=item.get("createdAt"),
    )


@router.get("/")
async def list_entries(
    request: Request, type: str | None = None,
) -> list[JournalEntryResponse]:
    repo = JournalRepository()
    items = repo.list_all(request.state.user_id, entry_type=type)
    return [_to_response(i) for i in items]


@router.get("/{entry_id}")
async def get_entry(request: Request, entry_id: str) -> JournalEntryResponse:
    repo = JournalRepository()
    item = repo.get(request.state.user_id, entry_id)
    return _to_response(item)


@router.post("/")
async def create_entry(
    request: Request, body: CreateJournalEntryRequest,
) -> JournalEntryResponse:
    repo = JournalRepository()
    data = body.model_dump(by_alias=True)
    item = repo.create(request.state.user_id, data)
    return _to_response(item)


@router.patch("/{entry_id}")
async def update_entry(
    request: Request, entry_id: str, body: UpdateJournalEntryRequest,
) -> JournalEntryResponse:
    repo = JournalRepository()
    item = repo.update(
        request.state.user_id, entry_id,
        body.model_dump(exclude_none=True),
    )
    return _to_response(item)


@router.delete("/{entry_id}")
async def delete_entry(request: Request, entry_id: str):
    repo = JournalRepository()
    repo.delete(request.state.user_id, entry_id)
    return Response(status_code=204)
