"""Routes for /api/memories — search, list, store, and delete.

Wired to MemoryService (GCS + faiss-cpu vector search).
"""

from __future__ import annotations

from fastapi import APIRouter, Query, Request, Response

from app.memory.memory_service import MemoryService
from app.models.responses import MemoryResponse

router = APIRouter(prefix="/memories", tags=["memories"])

_memory = MemoryService()


@router.get("/")
async def list_memories(request: Request) -> list[MemoryResponse]:
    """List all memory entries for the authenticated user."""
    user_id = request.state.user_id
    raw = _memory.list_memories(user_id)
    return [
        MemoryResponse(
            id=m.get("id", ""),
            user_id=user_id,
            content=m.get("content", ""),
            category=m.get("category", "fact"),
            importance=m.get("importance", "medium"),
            metadata=m.get("metadata"),
            created_at=m.get("createdAt"),
        )
        for m in raw
    ]


@router.get("/search")
async def search_memories(
    request: Request,
    q: str = Query(..., min_length=1, description="Search query"),
    category: str | None = Query(None, description="Filter by category"),
    top_k: int = Query(5, ge=1, le=50),
    min_importance: str = Query("low"),
) -> list[MemoryResponse]:
    """Semantic vector search over the user's long-term memory."""
    user_id = request.state.user_id
    results = _memory.search(
        user_id, q, top_k=top_k,
        category=category, min_importance=min_importance,
    )
    return [
        MemoryResponse(
            id=r.get("id", ""),
            user_id=user_id,
            content=r.get("content", ""),
            category=r.get("category", "fact"),
            importance=r.get("importance", "medium"),
            score=r.get("score"),
            metadata=r.get("metadata"),
            created_at=r.get("createdAt"),
        )
        for r in results
    ]


@router.post("/", status_code=201)
async def store_memory(request: Request) -> dict:
    """Store a structured memory entry."""
    user_id = request.state.user_id
    body = await request.json()
    content = body.get("content", "")
    category = body.get("category", "fact")
    importance = body.get("importance", "medium")
    metadata = body.get("metadata")

    if not content:
        return {"error": "content is required"}

    memory_id = _memory.store_structured(
        user_id, content, category, importance, metadata,
    )
    if memory_id:
        return {"id": memory_id, "status": "stored"}
    return {"error": "Failed to store memory (bucket not configured or embedding failed)"}


@router.delete("/{memory_id}")
async def delete_memory(request: Request, memory_id: str):
    """Delete a specific memory entry from GCS."""
    user_id = request.state.user_id
    _memory.delete(user_id, memory_id)
    return Response(status_code=204)
