"""Autonomous planning tools — the brain of goal achievement.

Borrowed from OpenClaw's proactive engine + workspace patterns:
- decompose_goal_into_plan: breaks a goal into milestones → tasks → reminders
- adapt_plan: reviews progress and adjusts the plan
- reschedule_failed_tasks: moves missed/failed tasks to new dates

These tools make the agent autonomous. When a user says "I want to learn
Spanish", the agent creates the goal AND immediately plans how to achieve it.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone

from app.db.repositories.goals import GoalsRepository
from app.db.repositories.tasks import TasksRepository
from app.db.repositories.reminders import RemindersRepository
from app.db.repositories.insights import InsightsRepository
from app.db.repositories.agent_context import AgentContextRepository


_goals_repo = GoalsRepository()
_tasks_repo = TasksRepository()
_reminders_repo = RemindersRepository()
_insights_repo = InsightsRepository()
_context_repo = AgentContextRepository()


def decompose_goal_into_plan(
    user_id: str,
    goal_id: str,
    milestones_json: str,
    tasks_json: str,
    reminders_json: str,
) -> dict:
    """Decompose a goal into milestones, tasks, and reminders — all at once.

    This is the CORE planning tool. ALWAYS call this after creating a goal.
    When a user says "I want to run a marathon" or "I want to learn Spanish",
    you must think through phases, actionable tasks, and reminders, then call
    this to create the full achievement plan.

    Think through:
    1. What milestones break this goal into 3-5 phases?
    2. What specific daily/weekly tasks achieve each milestone?
    3. What reminders keep the user on track?

    Args:
        user_id: The authenticated user's ID.
        goal_id: The goal to plan for (must already exist).
        milestones_json: JSON array of milestone objects:
            [{"title": "...", "target": 25, "target_date": "2026-04-01"}]
        tasks_json: JSON array of task objects:
            [{"title": "...", "detail": "...", "type": "task|habit|event",
              "priority": "high|medium|low", "due_date": "2026-03-15"}]
        reminders_json: JSON array of reminder objects:
            [{"title": "...", "time": "Every Monday 8 AM"}]

    Returns:
        Summary of the created plan with counts and IDs.
    """
    try:
        goal = _goals_repo.get(user_id, goal_id)
    except Exception:
        return {"error": f"Goal {goal_id} not found"}

    # Parse inputs safely
    try:
        milestones = json.loads(milestones_json) if milestones_json else []
    except (json.JSONDecodeError, TypeError):
        milestones = []
    try:
        tasks = json.loads(tasks_json) if tasks_json else []
    except (json.JSONDecodeError, TypeError):
        tasks = []
    try:
        reminders = json.loads(reminders_json) if reminders_json else []
    except (json.JSONDecodeError, TypeError):
        reminders = []

    created_tasks = []
    created_reminders = []

    # Store milestones as insight records for tracking
    for i, ms in enumerate(milestones):
        _insights_repo.create(user_id, {
            "type": "milestone",
            "title": f"Milestone {i + 1}: {ms.get('title', '')}",
            "content": json.dumps({
                "goalId": goal_id,
                "target": ms.get("target", 0),
                "targetDate": ms.get("target_date", ""),
                "index": i,
                "status": "pending",
            }),
            "relatedGoalId": goal_id,
        })

    # Create all tasks linked to the goal
    for t in tasks:
        # Calculate due date if not provided
        due_date = t.get("due_date", "")
        if not due_date and t.get("day_offset"):
            from datetime import timedelta
            offset = timedelta(days=int(t["day_offset"]))
            due_date = (datetime.now(timezone.utc) + offset).strftime("%Y-%m-%d")

        task = _tasks_repo.create(user_id, {
            "title": t.get("title", "Untitled task"),
            "detail": t.get("detail", ""),
            "type": t.get("type", "task"),
            "priority": t.get("priority", "medium"),
            "dueDate": due_date,
            "goalId": goal_id,
        })
        created_tasks.append({
            "id": task.get("id", task.get("taskId", "")),
            "title": task["title"],
            "dueDate": due_date,
        })

    # Create all reminders linked to the goal
    for r in reminders:
        reminder = _reminders_repo.create(user_id, {
            "title": r.get("title", ""),
            "time": r.get("time", ""),
            "goalId": goal_id,
        })
        created_reminders.append({
            "id": reminder.get("id", reminder.get("reminderId", "")),
            "title": reminder["title"],
        })

    # Update goal with plan summary
    _goals_repo.update(user_id, goal_id, {
        "insight": (
            f"Plan active: {len(milestones)} milestones, "
            f"{len(created_tasks)} tasks, {len(created_reminders)} reminders"
        ),
        "activeAgent": "planner",
    })

    # Publish to context bus
    _context_repo.publish(user_id, {
        "sourceAgent": "kai",
        "eventType": "plan_created",
        "summary": (
            f"Created plan for \"{goal.get('title', '')}\": "
            f"{len(milestones)} milestones, {len(created_tasks)} tasks, "
            f"{len(created_reminders)} reminders"
        ),
        "targetAgents": ["all"],
    })

    return {
        "goalId": goal_id,
        "goalTitle": goal.get("title", ""),
        "milestonesCreated": len(milestones),
        "tasksCreated": len(created_tasks),
        "remindersCreated": len(created_reminders),
        "tasks": created_tasks[:10],
        "reminders": created_reminders[:5],
    }


def adapt_plan(user_id: str, goal_id: str) -> dict:
    """Review a goal's progress and adapt the plan.

    Call this when:
    - The user reports progress or setbacks
    - A scheduled check-in fires
    - The user asks "how am I doing on X?"

    Analyzes completed vs pending tasks, velocity, and suggests
    whether to add tasks, reschedule, or celebrate.

    Args:
        user_id: The authenticated user's ID.
        goal_id: The goal to review.

    Returns:
        Analysis dict with status, recommendations, and stats.
    """
    try:
        goal = _goals_repo.get(user_id, goal_id)
    except Exception:
        return {"error": f"Goal {goal_id} not found"}

    all_tasks = _tasks_repo.list_all(user_id, goal_id=goal_id)
    completed = [t for t in all_tasks if t.get("completed")]
    pending = [t for t in all_tasks if not t.get("completed")]
    overdue = []
    now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    for t in pending:
        dd = t.get("dueDate", "")
        if dd and dd < now_iso:
            overdue.append(t)

    total = goal.get("total", 100)
    progress = goal.get("progress", 0)
    pct = round((progress / total) * 100) if total > 0 else 0
    velocity = round((len(completed) / len(all_tasks)) * 100) if all_tasks else 0

    # Determine status
    if pct >= 100:
        status = "completed"
    elif pct >= 80:
        status = "almost_done"
    elif len(overdue) > len(pending) // 2 and pending:
        status = "falling_behind"
    elif velocity >= 60:
        status = "on_track"
    elif len(all_tasks) == 0:
        status = "no_plan"
    else:
        status = "needs_attention"

    recommendations = []
    if status == "no_plan":
        recommendations.append("This goal has no tasks. Create a plan with decompose_goal_into_plan.")
    if status == "falling_behind":
        recommendations.append(
            f"{len(overdue)} tasks are overdue. Use reschedule_failed_tasks to move them forward."
        )
    if len(completed) == len(all_tasks) and all_tasks and pct < 100:
        recommendations.append(
            "All tasks done but goal not complete. Create new tasks to close the gap."
        )
    if status == "almost_done":
        remaining = total - progress
        recommendations.append(
            f"Only {remaining} {goal.get('unit', '')} to go! Push to finish."
        )
    if not pending and status not in ("completed", "no_plan"):
        recommendations.append("No pending tasks. Create next-phase tasks to maintain momentum.")

    return {
        "goalId": goal_id,
        "goalTitle": goal.get("title", ""),
        "status": status,
        "progress": progress,
        "total": total,
        "percentComplete": pct,
        "taskVelocity": velocity,
        "totalTasks": len(all_tasks),
        "completedTasks": len(completed),
        "pendingTasks": len(pending),
        "overdueTasks": len(overdue),
        "overdueTaskTitles": [t.get("title", "") for t in overdue[:5]],
        "recommendations": recommendations,
    }


def reschedule_failed_tasks(
    user_id: str,
    goal_id: str,
    days_forward: int,
) -> dict:
    """Reschedule overdue/failed tasks by pushing their due dates forward.

    Call this when adapt_plan reports overdue tasks, or when the user says
    they missed something and wants to try again.

    Args:
        user_id: The authenticated user's ID.
        goal_id: The goal whose tasks to reschedule.
        days_forward: How many days to push overdue tasks forward. Use 3 as a reasonable default.

    Returns:
        Summary of rescheduled tasks.
    """
    from datetime import timedelta

    actual_days = days_forward if days_forward > 0 else 3

    all_tasks = _tasks_repo.list_all(user_id, goal_id=goal_id)
    now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    rescheduled = []

    for t in all_tasks:
        if t.get("completed"):
            continue
        dd = t.get("dueDate", "")
        if dd and dd < now_iso:
            try:
                old_date = datetime.strptime(dd, "%Y-%m-%d")
                new_date = datetime.now(timezone.utc) + timedelta(days=actual_days)
                new_dd = new_date.strftime("%Y-%m-%d")
                task_id = t.get("id", t.get("taskId", ""))
                _tasks_repo.update(user_id, task_id, {
                    "dueDate": new_dd,
                    "detail": f"{t.get('detail', '')} [rescheduled from {dd}]".strip(),
                })
                rescheduled.append({
                    "id": task_id,
                    "title": t.get("title", ""),
                    "oldDate": dd,
                    "newDate": new_dd,
                })
            except Exception:
                continue

    # Create an insight about the rescheduling
    if rescheduled:
        _insights_repo.create(user_id, {
            "type": "reschedule",
            "title": f"Rescheduled {len(rescheduled)} tasks",
            "content": f"Moved {len(rescheduled)} overdue tasks forward by {actual_days} days.",
            "relatedGoalId": goal_id,
        })

    return {
        "goalId": goal_id,
        "rescheduledCount": len(rescheduled),
        "daysPushed": actual_days,
        "tasks": rescheduled[:10],
    }
