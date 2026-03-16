"""Agent tools for goal management — full CRUD.

Plain functions wrapped by ADK FunctionTool. The agent_service
injects user_id via tool_context or functools.partial.
"""

from __future__ import annotations

from app.db.repositories.goals import GoalsRepository
from app.db.repositories.tasks import TasksRepository
from app.db.repositories.agent_context import AgentContextRepository


_goals_repo = GoalsRepository()
_tasks_repo = TasksRepository()
_context_repo = AgentContextRepository()


def get_goals(user_id: str) -> list[dict]:
    """Retrieve all user goals with progress, categories, and insights.

    Use this to review the user's current goals before providing status
    updates, recommendations, or planning new actions.

    Args:
        user_id: The authenticated user's ID.

    Returns:
        List of goal dicts with id, title, category, progress, total, unit,
        insight, completed, and activeAgent fields.
    """
    goals = _goals_repo.list_all(user_id)
    return [
        {
            "id": g.get("id", g.get("goalId", "")),
            "title": g.get("title", ""),
            "category": g.get("category", ""),
            "progress": g.get("progress", 0),
            "total": g.get("total", 100),
            "unit": g.get("unit", ""),
            "insight": g.get("insight", ""),
            "completed": g.get("completed", False),
            "activeAgent": g.get("activeAgent", ""),
        }
        for g in goals
    ]


def create_goal(
    user_id: str,
    title: str,
    category: str,
    total: int,
    unit: str,
    insight: str,
) -> dict:
    """Create a new goal for the user.

    After creating a goal, you MUST immediately call decompose_goal_into_plan
    to break it into milestones, tasks, and reminders. Never leave a goal
    without a plan.

    Args:
        user_id: The authenticated user's ID.
        title: Goal title (e.g. "Run a half marathon").
        category: One of: Health, Learning, Finance, Personal, Professional, Creative. Use "Personal" if unsure.
        total: Target number to reach (e.g. 21 for 21km). Use 100 for percentage-based goals.
        unit: Unit of measurement (km, lessons, $, books, %, etc). Use "%" for percentage-based goals.
        insight: Initial motivational insight or strategy tip. Use empty string if none.

    Returns:
        The created goal dict with its ID.
    """
    goal = _goals_repo.create(user_id, {
        "title": title,
        "category": category or "Personal",
        "total": total if total > 0 else 100,
        "unit": unit or "%",
        "insight": insight,
    })

    # Publish to context bus so Kai can plan tasks
    _context_repo.publish(user_id, {
        "sourceAgent": "sage",
        "eventType": "goal_created",
        "summary": f"New {category} goal: \"{title}\" (target: {total} {unit})",
        "details": {"goalId": goal.get("id", goal.get("goalId", ""))},
        "targetAgents": ["all"],
    })

    return {
        "id": goal.get("id", goal.get("goalId", "")),
        "title": goal["title"],
        "category": goal["category"],
        "total": goal["total"],
        "unit": goal["unit"],
    }


def update_goal(
    user_id: str,
    goal_id: str,
    progress: int,
    insight: str,
    completed: str,
    title: str,
    category: str,
    total: int,
    unit: str,
) -> dict:
    """Update a goal's progress, insight, completion status, or other fields.

    Use get_goals first to find the goal ID.
    Only provide fields you want to change. Use -1 for ints and empty string for strings to skip.

    Args:
        user_id: The authenticated user's ID.
        goal_id: The goal ID to update.
        progress: New progress value. Use -1 to skip.
        insight: Updated AI insight about the goal. Use empty string to skip.
        completed: Mark goal as completed ("true"/"false"). Use empty string to skip.
        title: New title. Use empty string to skip.
        category: New category. Use empty string to skip.
        total: New target total. Use -1 to skip.
        unit: New unit. Use empty string to skip.

    Returns:
        The updated goal dict.
    """
    updates: dict = {}
    if progress != -1:
        updates["progress"] = progress
    if insight:
        updates["insight"] = insight
    if completed:
        updates["completed"] = completed.lower() == "true"
    if title:
        updates["title"] = title
    if category:
        updates["category"] = category
    if total != -1:
        updates["total"] = total
    if unit:
        updates["unit"] = unit

    try:
        goal = _goals_repo.update(user_id, goal_id, updates)

        # Publish completion to context bus
        if completed:
            _context_repo.publish(user_id, {
                "sourceAgent": "sage",
                "eventType": "goal_completed",
                "summary": f"Goal completed: \"{goal.get('title', '')}\"",
                "targetAgents": ["all"],
            })

        return {
            "id": goal.get("id", goal.get("goalId", "")),
            "title": goal.get("title", ""),
            "progress": goal.get("progress", 0),
            "total": goal.get("total", 100),
            "unit": goal.get("unit", ""),
            "completed": goal.get("completed", False),
        }
    except Exception:
        return {"error": "Goal not found"}


def delete_goal(user_id: str, goal_id: str) -> dict:
    """Delete a goal and all its linked tasks permanently.

    Warn the user before deleting. Use get_goals first to find the goal ID.

    Args:
        user_id: The authenticated user's ID.
        goal_id: The goal ID to delete.

    Returns:
        Confirmation dict.
    """
    # Also clean up linked tasks
    linked_tasks = _tasks_repo.list_all(user_id, goal_id=goal_id)
    for t in linked_tasks:
        try:
            _tasks_repo.delete(user_id, t.get("id", t.get("taskId", "")))
        except Exception:
            pass

    _goals_repo.delete(user_id, goal_id)
    return {"success": True, "deleted": goal_id, "linkedTasksRemoved": len(linked_tasks)}
