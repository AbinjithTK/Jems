"""Direct agent tool invocation endpoints.

These bypass the chat flow and call agent tools directly from UI buttons.
Results are returned as structured JSON, not chat messages.
"""

from __future__ import annotations

from fastapi import APIRouter, Request

from app.agent.tools.analysis_tools import (
    analyze_progress,
    get_daily_summary,
    smart_suggest,
)
from app.agent.tools.planning_tools import (
    adapt_plan,
    decompose_goal_into_plan,
    reschedule_failed_tasks,
)

router = APIRouter(prefix="/agent-actions", tags=["agent-actions"])


@router.get("/daily-summary")
async def daily_summary(request: Request) -> dict:
    """Get the user's daily summary (tasks, goals, reminders overview)."""
    return get_daily_summary(request.state.user_id)


@router.get("/analyze-progress")
async def progress_analysis(request: Request) -> dict:
    """Deep analysis of progress across all goals and tasks."""
    return analyze_progress(request.state.user_id)


@router.get("/smart-suggest")
async def suggestions(request: Request, focus: str = "all") -> dict:
    """Get smart suggestions based on current state."""
    return smart_suggest(request.state.user_id, focus=focus)


@router.post("/goals/{goal_id}/plan")
async def create_goal_plan(request: Request, goal_id: str) -> dict:
    """Decompose a goal into milestones, tasks, and reminders.

    Body: {"milestones": [...], "tasks": [...], "reminders": [...]}
    Each as JSON strings matching decompose_goal_into_plan signature.
    """
    body = await request.json()
    return decompose_goal_into_plan(
        user_id=request.state.user_id,
        goal_id=goal_id,
        milestones_json=body.get("milestones", "[]"),
        tasks_json=body.get("tasks", "[]"),
        reminders_json=body.get("reminders", "[]"),
    )


@router.post("/goals/{goal_id}/adapt")
async def adapt_goal_plan(request: Request, goal_id: str) -> dict:
    """Review a goal's progress and get adaptation recommendations."""
    return adapt_plan(request.state.user_id, goal_id)


@router.post("/goals/{goal_id}/reschedule")
async def reschedule_goal_tasks(
    request: Request, goal_id: str, days: int = 3,
) -> dict:
    """Reschedule overdue tasks for a goal."""
    return reschedule_failed_tasks(request.state.user_id, goal_id, days)
