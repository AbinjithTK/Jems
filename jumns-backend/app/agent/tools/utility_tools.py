"""Utility tools — data queries, search, datetime.

Mirrors OpenClaw's query_user_data, search_data, and get_current_datetime.
"""

from __future__ import annotations

from datetime import datetime, timezone

from app.db.repositories.goals import GoalsRepository
from app.db.repositories.tasks import TasksRepository
from app.db.repositories.reminders import RemindersRepository
from app.db.repositories.skills import SkillsRepository


_goals_repo = GoalsRepository()
_tasks_repo = TasksRepository()
_reminders_repo = RemindersRepository()
_skills_repo = SkillsRepository()


def query_user_data(user_id: str, data_type: str) -> dict:
    """Query the user's stored data across all entity types.

    Args:
        user_id: The authenticated user's ID.
        data_type: Which data to fetch — "goals", "tasks", "reminders",
                   "skills", or "all" for everything. Use "all" as default.

    Returns:
        Dict with requested data keyed by type.
    """
    actual_type = data_type if data_type else "all"
    result: dict = {}
    types = (
        ["goals", "tasks", "reminders", "skills"]
        if actual_type == "all"
        else [actual_type]
    )

    if "goals" in types:
        result["goals"] = _goals_repo.list_all(user_id)
    if "tasks" in types:
        result["tasks"] = _tasks_repo.list_all(user_id)
    if "reminders" in types:
        result["reminders"] = _reminders_repo.list_all(user_id)
    if "skills" in types:
        result["skills"] = _skills_repo.list_all(user_id)

    return result


def search_data(user_id: str, query: str) -> dict:
    """Search across goals, tasks, and reminders by keyword.

    Use when the user asks about something specific and you need to find it.

    Args:
        user_id: The authenticated user's ID.
        query: Search keyword or phrase.

    Returns:
        Dict with matching goals, tasks, and reminders.
    """
    q = query.lower()
    goals = _goals_repo.list_all(user_id)
    tasks = _tasks_repo.list_all(user_id)
    reminders = _reminders_repo.list_all(user_id)

    return {
        "goals": [
            {"id": g.get("id", g.get("goalId", "")), "title": g.get("title", ""),
             "category": g.get("category", "")}
            for g in goals
            if q in g.get("title", "").lower() or q in g.get("category", "").lower()
        ],
        "tasks": [
            {"id": t.get("id", t.get("taskId", "")), "title": t.get("title", ""),
             "type": t.get("type", "task"), "completed": t.get("completed", False)}
            for t in tasks
            if q in t.get("title", "").lower() or q in t.get("detail", "").lower()
        ],
        "reminders": [
            {"id": r.get("id", r.get("reminderId", "")), "title": r.get("title", "")}
            for r in reminders
            if q in r.get("title", "").lower()
        ],
    }


def get_current_datetime(timezone_str: str) -> str:
    """Return the current date and time as a human-readable string.

    Args:
        timezone_str: IANA timezone name (currently only UTC supported). Use "UTC" as default.

    Returns:
        Formatted datetime string.
    """
    now = datetime.now(timezone.utc)
    return now.strftime("%A, %B %d, %Y at %I:%M %p UTC")
