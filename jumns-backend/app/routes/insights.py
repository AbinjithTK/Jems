"""Routes for /api/insights — list, read/dismiss, unread count, trigger engine."""

from fastapi import APIRouter, Request

from app.agent.agent_service import AgentService
from app.db.repositories.insights import InsightsRepository
from app.models.responses import InsightResponse

router = APIRouter(prefix="/insights", tags=["insights"])


def _to_response(item: dict) -> InsightResponse:
    return InsightResponse(
        id=item.get("id", ""),
        user_id=item["userId"],
        type=item.get("type", "general"),
        title=item.get("title", ""),
        content=item.get("content", ""),
        related_goal_id=item.get("relatedGoalId"),
        created_at=item.get("createdAt"),
    )


@router.get("/")
async def list_insights(request: Request) -> list[InsightResponse]:
    repo = InsightsRepository()
    return [_to_response(i) for i in repo.list_all(request.state.user_id)]


@router.get("/unread")
async def unread_count(request: Request) -> dict:
    """Return count of unread, non-dismissed insights."""
    repo = InsightsRepository()
    count = repo.unread_count(request.state.user_id)
    return {"count": count}


@router.post("/{insight_id}/read")
async def mark_read(request: Request, insight_id: str) -> dict:
    """Mark a single insight as read."""
    repo = InsightsRepository()
    repo.mark_read(request.state.user_id, insight_id)
    return {"ok": True}


@router.post("/{insight_id}/dismiss")
async def dismiss_insight(request: Request, insight_id: str) -> dict:
    """Dismiss a single insight (hides it from the list)."""
    repo = InsightsRepository()
    repo.dismiss(request.state.user_id, insight_id)
    return {"ok": True}


@router.post("/run")
async def trigger_proactive(request: Request) -> dict:
    """Manually trigger the proactive engine for the current user."""
    user_id = request.state.user_id
    agent = AgentService()
    results = []

    for prompt_type in ("plan_review", "smart_suggestions"):
        try:
            result = await agent.invoke_proactive(user_id, prompt_type)
            if result:
                results.append({
                    "type": prompt_type,
                    "content": result.get("content", ""),
                    "cardType": result.get("cardType"),
                    "cardData": result.get("cardData"),
                })
        except Exception:
            pass

    return {"triggered": True, "results": results}
