"""Analysis tools — progress tracking, smart suggestions, daily summaries.

Mirrors OpenClaw's analyze_progress, smart_suggest, and get_daily_summary
tools from the Projectj ai-agent.ts.
"""

from __future__ import annotations

import math

from app.db.repositories.goals import GoalsRepository
from app.db.repositories.tasks import TasksRepository
from app.db.repositories.reminders import RemindersRepository


_goals_repo = GoalsRepository()
_tasks_repo = TasksRepository()
_reminders_repo = RemindersRepository()


def get_daily_summary(user_id: str) -> dict:
    """Get a comprehensive summary of the user's day.

    Use for daily briefings, planning, or when the user asks
    "how am I doing?" or "what's on my plate?".

    Args:
        user_id: The authenticated user's ID.

    Returns:
        Summary dict with goals, tasks, reminders, and overall progress.
    """
    goals = _goals_repo.list_all(user_id)
    tasks = _tasks_repo.list_all(user_id)
    reminders = _reminders_repo.list_all(user_id)

    completed_tasks = [t for t in tasks if t.get("completed")]
    pending_tasks = [t for t in tasks if not t.get("completed")]
    active_goals = [g for g in goals if not g.get("completed")]

    return {
        "goals": {
            "active": [
                {
                    "id": g.get("id", g.get("goalId", "")),
                    "title": g.get("title", ""),
                    "category": g.get("category", ""),
                    "progress": g.get("progress", 0),
                    "total": g.get("total", 100),
                    "unit": g.get("unit", ""),
                    "percentComplete": (
                        round((g.get("progress", 0) / g.get("total", 100)) * 100)
                        if g.get("total", 100) > 0 else 0
                    ),
                }
                for g in active_goals
            ],
            "completedCount": len([g for g in goals if g.get("completed")]),
        },
        "tasks": {
            "completed": len(completed_tasks),
            "pending": len(pending_tasks),
            "total": len(tasks),
            "upcoming": [
                {
                    "id": t.get("id", t.get("taskId", "")),
                    "title": t.get("title", ""),
                    "time": t.get("time", ""),
                    "type": t.get("type", "task"),
                    "priority": t.get("priority", "medium"),
                }
                for t in pending_tasks[:5]
            ],
        },
        "reminders": {
            "active": [
                {
                    "id": r.get("id", r.get("reminderId", "")),
                    "title": r.get("title", ""),
                    "time": r.get("time", ""),
                }
                for r in reminders if r.get("active")
            ],
        },
        "overallProgress": (
            round((len(completed_tasks) / len(tasks)) * 100)
            if tasks else 0
        ),
    }


def analyze_progress(user_id: str) -> dict:
    """Deep analysis of progress across all goals and tasks.

    Identifies patterns, bottlenecks, at-risk goals, and provides
    strategic recommendations. Use for weekly/monthly reviews or when
    the user asks "how am I really doing?".

    Args:
        user_id: The authenticated user's ID.

    Returns:
        Detailed analysis with goal breakdowns, risk assessment, and recommendations.
    """
    goals = _goals_repo.list_all(user_id)
    tasks = _tasks_repo.list_all(user_id)
    reminders = _reminders_repo.list_all(user_id)

    active_goals = [g for g in goals if not g.get("completed")]
    completed_goals = [g for g in goals if g.get("completed")]
    completed_tasks = [t for t in tasks if t.get("completed")]
    pending_tasks = [t for t in tasks if not t.get("completed")]

    goal_analysis = []
    at_risk = []
    almost_done = []

    for g in active_goals:
        gid = g.get("id", g.get("goalId", ""))
        total = g.get("total", 100)
        progress = g.get("progress", 0)
        pct = round((progress / total) * 100) if total > 0 else 0

        linked = [t for t in tasks if t.get("goalId") == gid]
        linked_done = [t for t in linked if t.get("completed")]
        velocity = round((len(linked_done) / len(linked)) * 100) if linked else 0

        if pct < 25 and len(linked_done) == 0:
            status = "at_risk"
        elif pct > 75:
            status = "almost_done"
        elif velocity < 30 and linked:
            status = "needs_attention"
        else:
            status = "on_track"

        entry = {
            "id": gid,
            "title": g.get("title", ""),
            "category": g.get("category", ""),
            "percentComplete": pct,
            "status": status,
            "linkedTasks": len(linked),
            "linkedCompleted": len(linked_done),
            "taskVelocity": velocity,
        }
        goal_analysis.append(entry)
        if status in ("at_risk", "needs_attention"):
            at_risk.append(entry)
        if status == "almost_done":
            almost_done.append(entry)

    # Category breakdown
    categories: dict[str, dict] = {}
    for g in goals:
        cat = g.get("category", "Other")
        if cat not in categories:
            categories[cat] = {"goals": 0, "completed": 0}
        categories[cat]["goals"] += 1
        if g.get("completed"):
            categories[cat]["completed"] += 1

    # Recommendations
    recs = []
    goals_no_tasks = [
        g for g in active_goals
        if not any(t.get("goalId") == g.get("id", g.get("goalId", "")) for t in tasks)
    ]
    if goals_no_tasks:
        recs.append(
            f"{len(goals_no_tasks)} goal(s) have no tasks. "
            "Use decompose_goal_into_plan to create action plans."
        )
    if len(pending_tasks) > 10:
        recs.append("Task overload detected. Focus on the top 3 highest-priority items.")
    if not [r for r in reminders if r.get("active")] and pending_tasks:
        recs.append("No active reminders. Setting reminders boosts completion rates.")
    if at_risk:
        recs.append(
            f"{len(at_risk)} goal(s) at risk: "
            + ", ".join(g["title"] for g in at_risk[:3])
        )

    return {
        "summary": {
            "totalGoals": len(goals),
            "activeGoals": len(active_goals),
            "completedGoals": len(completed_goals),
            "totalTasks": len(tasks),
            "completedTasks": len(completed_tasks),
            "pendingTasks": len(pending_tasks),
            "activeReminders": len([r for r in reminders if r.get("active")]),
            "overallCompletionRate": (
                round((len(completed_tasks) / len(tasks)) * 100) if tasks else 0
            ),
        },
        "goalAnalysis": goal_analysis,
        "atRiskGoals": at_risk,
        "almostDoneGoals": almost_done,
        "categoryBreakdown": categories,
        "recommendations": recs,
    }


def smart_suggest(user_id: str, focus: str) -> dict:
    """Generate smart suggestions based on current goals, tasks, and patterns.

    Use proactively to offer helpful next steps, or when the user says
    "what should I do next?" or "any suggestions?".

    Args:
        user_id: The authenticated user's ID.
        focus: Focus area: "goals", "tasks", "habits", "productivity", or "all". Use "all" as default.

    Returns:
        List of prioritized suggestions.
    """
    actual_focus = focus if focus else "all"
    goals = _goals_repo.list_all(user_id)
    tasks = _tasks_repo.list_all(user_id)
    reminders = _reminders_repo.list_all(user_id)
    suggestions: list[dict] = []

    # Goals without tasks
    for g in goals:
        if g.get("completed"):
            continue
        gid = g.get("id", g.get("goalId", ""))
        linked = [t for t in tasks if t.get("goalId") == gid]
        if not linked:
            suggestions.append({
                "type": "missing_tasks",
                "suggestion": f'Goal "{g.get("title", "")}" has no tasks. Create a plan to make progress.',
                "priority": "high",
                "relatedGoal": g.get("title", ""),
            })

    # Stale goals (all tasks done but goal not complete)
    for g in goals:
        if g.get("completed"):
            continue
        gid = g.get("id", g.get("goalId", ""))
        linked = [t for t in tasks if t.get("goalId") == gid]
        if linked and all(t.get("completed") for t in linked):
            total = g.get("total", 100)
            progress = g.get("progress", 0)
            if progress < total:
                suggestions.append({
                    "type": "stale_goal",
                    "suggestion": (
                        f'All tasks for "{g.get("title", "")}" are done but goal is at '
                        f'{progress}/{total} {g.get("unit", "")}. Create new tasks.'
                    ),
                    "priority": "medium",
                    "relatedGoal": g.get("title", ""),
                })

    # Near completion
    for g in goals:
        if g.get("completed"):
            continue
        total = g.get("total", 100)
        progress = g.get("progress", 0)
        if total > 0 and (progress / total) > 0.85:
            suggestions.append({
                "type": "near_completion",
                "suggestion": (
                    f'You\'re {round((progress / total) * 100)}% done with '
                    f'"{g.get("title", "")}"! Just {total - progress} {g.get("unit", "")} to go.'
                ),
                "priority": "high",
                "relatedGoal": g.get("title", ""),
            })

    # Task overload
    pending = [t for t in tasks if not t.get("completed")]
    if len(pending) > 10:
        suggestions.append({
            "type": "task_overload",
            "suggestion": f"You have {len(pending)} pending tasks. Focus on the top 3 highest priority.",
            "priority": "medium",
        })

    # Habits reminder
    habits = [t for t in tasks if t.get("type") == "habit" and not t.get("completed")]
    if habits:
        suggestions.append({
            "type": "habit_reminder",
            "suggestion": (
                f"You have {len(habits)} habits to complete: "
                + ", ".join(t.get("title", "") for t in habits[:3])
            ),
            "priority": "medium",
        })

    # No reminders
    active_reminders = [r for r in reminders if r.get("active")]
    if not active_reminders and pending:
        suggestions.append({
            "type": "no_reminders",
            "suggestion": "You have tasks but no reminders. Reminders boost completion by 40%.",
            "priority": "medium",
        })

    return {
        "suggestions": suggestions[:8],
        "focusArea": focus,
        "totalSuggestions": len(suggestions),
    }
