"""CRUD routes for /api/goals."""

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Request, Response

from app.db.repositories.goals import GoalsRepository
from app.db.repositories.tasks import TasksRepository
from app.models.requests import CreateGoalRequest, UpdateGoalRequest
from app.models.responses import GoalResponse

router = APIRouter(prefix="/goals", tags=["goals"])


def _to_response(item: dict) -> GoalResponse:
    return GoalResponse(
        id=item.get("id", item.get("goalId", "")),
        user_id=item["userId"],
        title=item["title"],
        category=item.get("category", "personal"),
        progress=item.get("progress", 0),
        total=item.get("total", 100),
        unit=item.get("unit", ""),
        insight=item.get("insight", ""),
        active_agent=item.get("activeAgent", ""),
        completed=item.get("completed", False),
        created_at=item.get("createdAt"),
    )


@router.get("/weekly-progress")
async def weekly_progress(request: Request) -> dict:
    """Task completion counts per day for the current week (Mon-Sun)."""
    user_id = request.state.user_id
    tasks_repo = TasksRepository()
    all_tasks = tasks_repo.list_all(user_id)

    today = datetime.now(timezone.utc).date()
    # Monday of this week
    monday = today - timedelta(days=today.weekday())

    counts = [0] * 7  # Mon=0 .. Sun=6
    total = 0
    for t in all_tasks:
        if not t.get("completed"):
            continue
        completed_at = t.get("completedAt")
        if not completed_at:
            continue
        try:
            dt = datetime.fromisoformat(completed_at.replace("Z", "+00:00")).date()
        except (ValueError, AttributeError):
            continue
        day_offset = (dt - monday).days
        if 0 <= day_offset < 7:
            counts[day_offset] += 1
            total += 1

    best_day = counts.index(max(counts)) if total > 0 else -1
    return {"counts": counts, "total": total, "bestDay": best_day}


@router.get("/")
async def list_goals(request: Request) -> list[GoalResponse]:
    repo = GoalsRepository()
    items = repo.list_all(request.state.user_id)
    return [_to_response(i) for i in items]


@router.get("/{goal_id}")
async def get_goal(request: Request, goal_id: str) -> GoalResponse:
    repo = GoalsRepository()
    item = repo.get(request.state.user_id, goal_id)
    return _to_response(item)


@router.post("/")
async def create_goal(request: Request, body: CreateGoalRequest) -> GoalResponse:
    repo = GoalsRepository()
    item = repo.create(request.state.user_id, body.model_dump())
    return _to_response(item)


@router.patch("/{goal_id}")
async def update_goal(
    request: Request, goal_id: str, body: UpdateGoalRequest
) -> GoalResponse:
    repo = GoalsRepository()
    item = repo.update(
        request.state.user_id, goal_id, body.model_dump(exclude_none=True)
    )
    return _to_response(item)


@router.delete("/{goal_id}")
async def delete_goal(request: Request, goal_id: str):
    repo = GoalsRepository()
    repo.delete(request.state.user_id, goal_id)
    return Response(status_code=204)
