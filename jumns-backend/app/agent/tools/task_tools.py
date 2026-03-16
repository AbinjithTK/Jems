"""Agent tools for task management — full CRUD + completion."""

from __future__ import annotations

from app.db.repositories.tasks import TasksRepository


_tasks_repo = TasksRepository()


def get_tasks(user_id: str, goal_id: str) -> list[dict]:
    """Get all tasks, optionally filtered by goal.

    Args:
        user_id: The authenticated user's ID.
        goal_id: Goal ID to filter tasks by. Use empty string for all tasks.

    Returns:
        List of task dicts.
    """
    tasks = _tasks_repo.list_all(user_id, goal_id=goal_id or None)
    return [
        {
            "id": t.get("id", t.get("taskId", "")),
            "title": t.get("title", ""),
            "time": t.get("time", ""),
            "detail": t.get("detail", ""),
            "type": t.get("type", "task"),
            "completed": t.get("completed", False),
            "active": t.get("active", False),
            "goalId": t.get("goalId"),
            "priority": t.get("priority", "medium"),
            "dueDate": t.get("dueDate"),
            "requiresProof": t.get("requiresProof", False),
            "proofStatus": t.get("proofStatus", "pending"),
        }
        for t in tasks
    ]


def create_task(
    user_id: str,
    title: str,
    time: str,
    detail: str,
    type: str,
    goal_id: str,
    priority: str,
    due_date: str,
    requires_proof: str,
) -> dict:
    """Create a new task, habit, or event.

    Link to a goal with goal_id if relevant. Set requires_proof to "true"
    ONLY for important tasks that need photo/video verification.

    Args:
        user_id: The authenticated user's ID.
        title: Task title.
        time: Scheduled time (e.g. "9:00 AM", "Tomorrow 3 PM"). Use empty string if none.
        detail: Additional context or notes. Use empty string if none.
        type: One of: task, habit, event. Use "task" if unsure.
        goal_id: Link to a goal ID if this task supports a goal. Use empty string if none.
        priority: Priority level: high, medium, or low. Use "medium" if unsure.
        due_date: ISO 8601 date string for the deadline. Use empty string if none.
        requires_proof: "true" if this task requires photo/video proof, "false" otherwise.

    Returns:
        The created task dict.
    """
    data: dict = {
        "title": title,
        "time": time,
        "detail": detail,
        "type": type or "task",
        "priority": priority or "medium",
        "requiresProof": requires_proof.lower() == "true" if requires_proof else False,
    }
    if goal_id:
        data["goalId"] = goal_id
    if due_date:
        data["dueDate"] = due_date

    task = _tasks_repo.create(user_id, data)
    return {
        "id": task.get("id", task.get("taskId", "")),
        "title": task["title"],
        "type": task.get("type", "task"),
        "goalId": task.get("goalId"),
        "priority": task.get("priority", "medium"),
    }


def update_task(
    user_id: str,
    task_id: str,
    title: str,
    time: str,
    detail: str,
    active: str,
    priority: str,
    due_date: str,
    type: str,
) -> dict:
    """Update a task's details. Cannot mark as completed — use complete_task.

    Only provide fields you want to change. Use empty string to skip a field.

    Args:
        user_id: The authenticated user's ID.
        task_id: The task ID to update.
        title: New title. Use empty string to skip.
        time: New time. Use empty string to skip.
        detail: New detail. Use empty string to skip.
        active: Set to "true" or "false" to change active status. Use empty string to skip.
        priority: New priority. Use empty string to skip.
        due_date: New due date. Use empty string to skip.
        type: New type (task/habit/event). Use empty string to skip.

    Returns:
        The updated task dict.
    """
    updates: dict = {}
    if title:
        updates["title"] = title
    if time:
        updates["time"] = time
    if detail:
        updates["detail"] = detail
    if active:
        updates["active"] = active.lower() == "true"
    if priority:
        updates["priority"] = priority
    if due_date:
        updates["dueDate"] = due_date
    if type:
        updates["type"] = type

    try:
        task = _tasks_repo.update(user_id, task_id, updates)
        return {
            "id": task.get("id", task.get("taskId", "")),
            "title": task.get("title", ""),
            "completed": task.get("completed", False),
        }
    except Exception:
        return {"error": "Task not found"}


def complete_task(user_id: str, task_id: str) -> dict:
    """Mark a task as completed.

    After completing a task linked to a goal, consider updating the goal's
    progress and checking if the plan needs adaptation.

    Args:
        user_id: The authenticated user's ID.
        task_id: The task to complete.

    Returns:
        The updated task dict.
    """
    try:
        task = _tasks_repo.complete(user_id, task_id, {})
        return {
            "id": task.get("id", task.get("taskId", "")),
            "title": task.get("title", ""),
            "completed": True,
            "goalId": task.get("goalId"),
        }
    except Exception:
        return {"error": "Task not found"}


def delete_task(user_id: str, task_id: str) -> dict:
    """Delete a task permanently.

    Args:
        user_id: The authenticated user's ID.
        task_id: The task ID to delete.

    Returns:
        Confirmation dict.
    """
    _tasks_repo.delete(user_id, task_id)
    return {"success": True, "deleted": task_id}
