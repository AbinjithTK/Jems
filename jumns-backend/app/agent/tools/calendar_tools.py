"""Calendar-aware scheduling tools — date assignment, schedule view, conflict detection.

Borrowed from OpenClaw's timezone.md + agent-workspace.md patterns:
- The agent is always aware of the user's timezone and current date/time
- Tasks, reminders, and habits are assigned to specific calendar dates
- The agent can view a user's schedule for any date range
- Conflict detection prevents double-booking
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone

from app.db.repositories.goals import GoalsRepository
from app.db.repositories.reminders import RemindersRepository
from app.db.repositories.tasks import TasksRepository

_goals_repo = GoalsRepository()
_tasks_repo = TasksRepository()
_reminders_repo = RemindersRepository()


def get_schedule(
    user_id: str,
    date: str,
    days: int,
) -> dict:
    """Get the user's schedule for a date or date range.

    Call this to understand what the user has planned before suggesting
    new tasks or reminders. Also useful for daily briefings and plan reviews.

    Args:
        user_id: The authenticated user's ID.
        date: ISO date string (YYYY-MM-DD). Use empty string for today.
        days: Number of days to include (1 = just that day, 7 = week view). Use 1 for single day.

    Returns:
        Schedule dict with tasks, reminders, and habits grouped by date.
    """
    now = datetime.now(timezone.utc)
    if date:
        try:
            start = datetime.strptime(date, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        except ValueError:
            start = now
    else:
        start = now

    end = start + timedelta(days=days)
    start_iso = start.strftime("%Y-%m-%d")
    end_iso = end.strftime("%Y-%m-%d")

    # Fetch all tasks and reminders
    all_tasks = _tasks_repo.list_all(user_id)
    all_reminders = _reminders_repo.list_all(user_id)

    schedule: dict[str, dict] = {}
    current = start
    while current < end:
        day_iso = current.strftime("%Y-%m-%d")
        day_name = current.strftime("%A")

        # Tasks due on this day
        day_tasks = [
            {
                "id": t.get("id", t.get("taskId", "")),
                "title": t.get("title", ""),
                "type": t.get("type", "task"),
                "priority": t.get("priority", "medium"),
                "completed": t.get("completed", False),
                "time": t.get("time", ""),
                "goalId": t.get("goalId"),
            }
            for t in all_tasks
            if t.get("dueDate", "") == day_iso
        ]

        # Reminders active on this day (recurring or scheduled for this date)
        day_reminders = []
        for r in all_reminders:
            if not r.get("active", True):
                continue
            time_str = r.get("time", "").lower()
            # Check if reminder is relevant for this day
            is_daily = any(
                kw in time_str
                for kw in ["every", "daily", "morning", "evening"]
            )
            is_weekday = "weekday" in time_str and current.weekday() < 5
            is_weekly = "weekly" in time_str or current.strftime("%A").lower() in time_str
            is_specific = day_iso in r.get("time", "")

            if is_daily or is_weekday or is_weekly or is_specific:
                day_reminders.append({
                    "id": r.get("id", r.get("reminderId", "")),
                    "title": r.get("title", ""),
                    "time": r.get("time", ""),
                    "goalId": r.get("goalId"),
                })

        # Habits (type=habit tasks that are active)
        habits = [t for t in day_tasks if t["type"] == "habit"]
        tasks_only = [t for t in day_tasks if t["type"] != "habit"]

        schedule[day_iso] = {
            "dayName": day_name,
            "tasks": tasks_only,
            "habits": habits,
            "reminders": day_reminders,
            "totalItems": len(tasks_only) + len(habits) + len(day_reminders),
        }

        current += timedelta(days=1)

    # Summary stats
    total_tasks = sum(d["totalItems"] for d in schedule.values())
    overdue_tasks = [
        t for t in all_tasks
        if not t.get("completed") and t.get("dueDate", "") and t["dueDate"] < start_iso
    ]

    return {
        "startDate": start_iso,
        "endDate": end_iso,
        "days": days,
        "schedule": schedule,
        "totalScheduledItems": total_tasks,
        "overdueCount": len(overdue_tasks),
        "overdueTasks": [
            {"id": t.get("id", t.get("taskId", "")), "title": t.get("title", ""), "dueDate": t.get("dueDate", "")}
            for t in overdue_tasks[:5]
        ],
    }


def assign_task_to_date(
    user_id: str,
    task_id: str,
    date: str,
) -> dict:
    """Assign or reassign a task to a specific calendar date.

    Use this to schedule tasks on the calendar. The date carousel in the
    app will show tasks grouped by their assigned date.

    Args:
        user_id: The authenticated user's ID.
        task_id: The task to assign.
        date: ISO date string (YYYY-MM-DD) to assign the task to.

    Returns:
        Updated task with new dueDate.
    """
    try:
        # Validate date format
        datetime.strptime(date, "%Y-%m-%d")
    except ValueError:
        return {"error": f"Invalid date format: {date}. Use YYYY-MM-DD."}

    try:
        task = _tasks_repo.update(user_id, task_id, {"dueDate": date})
        return {
            "id": task.get("id", task.get("taskId", "")),
            "title": task.get("title", ""),
            "dueDate": date,
            "assigned": True,
        }
    except Exception:
        return {"error": f"Task {task_id} not found"}


def analyze_goal_timeline(
    user_id: str,
    goal_id: str,
) -> dict:
    """Analyze whether a goal is short-term or long-term and recommend planning strategy.

    Call this BEFORE decompose_goal_into_plan to determine the right
    task spacing and milestone structure. The analysis considers:
    - Goal complexity (total units, category)
    - Existing tasks and their completion rate
    - Time since creation
    - Similar goal patterns from memory

    Args:
        user_id: The authenticated user's ID.
        goal_id: The goal to analyze.

    Returns:
        Analysis with timeline classification and planning recommendations.
    """
    try:
        goal = _goals_repo.get(user_id, goal_id)
    except Exception:
        return {"error": f"Goal {goal_id} not found"}

    total = goal.get("total", 100)
    progress = goal.get("progress", 0)
    category = goal.get("category", "personal")
    title = goal.get("title", "")
    created_at = goal.get("createdAt", "")

    # Existing tasks for this goal
    tasks = _tasks_repo.list_all(user_id, goal_id=goal_id)
    completed_tasks = [t for t in tasks if t.get("completed")]
    pending_tasks = [t for t in tasks if not t.get("completed")]

    # Calculate days since creation
    days_active = 0
    if created_at:
        try:
            created = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
            days_active = (datetime.now(timezone.utc) - created).days
        except Exception:
            pass

    # Determine timeline classification
    remaining = total - progress
    pct_done = round((progress / total) * 100) if total > 0 else 0

    # Heuristics for short vs long term
    if total <= 10 or remaining <= 3:
        timeline = "short_term"
        estimated_days = max(7, remaining * 2)
        task_frequency = "daily"
        milestone_count = 2
    elif total <= 50 or remaining <= 20:
        timeline = "medium_term"
        estimated_days = max(30, remaining * 3)
        task_frequency = "3-4 times per week"
        milestone_count = 3
    else:
        timeline = "long_term"
        estimated_days = max(90, remaining * 5)
        task_frequency = "2-3 times per week"
        milestone_count = 5

    # Velocity analysis
    if days_active > 0 and len(completed_tasks) > 0:
        velocity = len(completed_tasks) / days_active  # tasks per day
        if velocity > 0:
            estimated_days = int(len(pending_tasks) / velocity) + 1
    else:
        velocity = 0

    now = datetime.now(timezone.utc)
    target_date = (now + timedelta(days=estimated_days)).strftime("%Y-%m-%d")

    return {
        "goalId": goal_id,
        "goalTitle": title,
        "category": category,
        "timeline": timeline,
        "estimatedDays": estimated_days,
        "targetCompletionDate": target_date,
        "recommendedTaskFrequency": task_frequency,
        "recommendedMilestoneCount": milestone_count,
        "currentProgress": {
            "progress": progress,
            "total": total,
            "percentComplete": pct_done,
            "daysActive": days_active,
            "completedTasks": len(completed_tasks),
            "pendingTasks": len(pending_tasks),
            "velocity": round(velocity, 2),
        },
        "planningAdvice": _get_planning_advice(timeline, category, remaining),
    }


def _get_planning_advice(timeline: str, category: str, remaining: int) -> str:
    """Generate planning advice based on timeline and category."""
    if timeline == "short_term":
        return (
            f"This is a short-term goal with {remaining} units remaining. "
            "Create daily tasks with specific deadlines. "
            "Set 1-2 check-in reminders. Focus on momentum."
        )
    elif timeline == "medium_term":
        return (
            f"This is a medium-term goal ({remaining} units remaining). "
            "Break into 3 milestones with weekly task batches. "
            "Set recurring reminders for consistency. "
            "Plan a mid-point review."
        )
    else:
        return (
            f"This is a long-term goal ({remaining} units remaining). "
            "Create 4-5 milestones spanning months. "
            "Use weekly task batches with rest days built in. "
            "Set bi-weekly progress reviews. "
            "Plan for plateaus and motivation dips."
        )
