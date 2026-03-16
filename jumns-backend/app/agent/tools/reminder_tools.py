"""Agent tools for reminder management — full CRUD + pause/resume + snooze."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from app.db.repositories.reminders import RemindersRepository


_reminders_repo = RemindersRepository()


def get_reminders(user_id: str) -> list[dict]:
    """Get all reminders for the user.

    Args:
        user_id: The authenticated user's ID.

    Returns:
        List of reminder dicts.
    """
    reminders = _reminders_repo.list_all(user_id)
    return [
        {
            "id": r.get("id", r.get("reminderId", "")),
            "title": r.get("title", ""),
            "time": r.get("time", ""),
            "active": r.get("active", True),
            "goalId": r.get("goalId"),
            "snoozeCount": r.get("snoozeCount", 0),
            "snoozedUntil": r.get("snoozedUntil"),
            "originalTime": r.get("originalTime"),
        }
        for r in reminders
    ]


def create_reminder(
    user_id: str,
    title: str,
    time: str,
    goal_id: str,
) -> dict:
    """Create a new reminder with a schedule.

    IMPORTANT: When creating plans, ALWAYS create reminders alongside tasks.
    Good reminders are specific and actionable:
    - "Review Spanish flashcards" at "Every morning 8 AM"
    - "Check marathon training progress" at "Every Sunday 6 PM"
    - "Take medication" at "Daily 9 AM and 9 PM"

    Args:
        user_id: The authenticated user's ID.
        title: What to remind about.
        time: When — e.g. "Today 5:00 PM", "Every morning", "Weekdays 8 AM". Use empty string if unspecified.
        goal_id: Link to a goal if relevant. Use empty string if none.

    Returns:
        The created reminder dict.
    """
    data: dict = {"title": title, "time": time}
    if goal_id:
        data["goalId"] = goal_id

    reminder = _reminders_repo.create(user_id, data)
    return {
        "id": reminder.get("id", reminder.get("reminderId", "")),
        "title": reminder["title"],
        "time": reminder.get("time", ""),
    }


def update_reminder(
    user_id: str,
    reminder_id: str,
    title: str,
    time: str,
    active: str,
) -> dict:
    """Update a reminder's title, time, or active status (pause/resume).

    Args:
        user_id: The authenticated user's ID.
        reminder_id: The reminder ID to update.
        title: New title. Use empty string to skip.
        time: New schedule. Use empty string to skip.
        active: Set to "false" to pause, "true" to resume. Use empty string to skip.

    Returns:
        The updated reminder dict.
    """
    updates: dict = {}
    if title:
        updates["title"] = title
    if time:
        updates["time"] = time
    if active:
        updates["active"] = active.lower() == "true"

    try:
        reminder = _reminders_repo.update(user_id, reminder_id, updates)
        return {
            "id": reminder.get("id", reminder.get("reminderId", "")),
            "title": reminder.get("title", ""),
            "time": reminder.get("time", ""),
            "active": reminder.get("active", True),
        }
    except Exception:
        return {"error": "Reminder not found"}


def snooze_reminder(
    user_id: str,
    reminder_id: str,
    minutes: int,
) -> dict:
    """Snooze a reminder by pushing it forward.

    Call this when the user says "snooze", "remind me later", "not now",
    or when the agent detects the user is busy. The reminder's time is
    updated and snoozeCount is incremented. After 3+ snoozes, consider
    suggesting the user reschedule or remove the reminder.

    Args:
        user_id: The authenticated user's ID.
        reminder_id: The reminder to snooze.
        minutes: How many minutes to push forward (use 30 as default, max 1440).

    Returns:
        Updated reminder with new time and snooze count.
    """
    try:
        actual_minutes = minutes if minutes > 0 else 30
        result = _reminders_repo.snooze(user_id, reminder_id, actual_minutes)
        snooze_count = result.get("snoozeCount", 0)
        response = {
            "id": result.get("id", result.get("reminderId", "")),
            "title": result.get("title", ""),
            "time": result.get("time", ""),
            "snoozeCount": snooze_count,
            "snoozedUntil": result.get("snoozedUntil"),
        }
        if snooze_count >= 3:
            response["warning"] = (
                f"This reminder has been snoozed {snooze_count} times. "
                "Consider asking the user if they want to reschedule or remove it."
            )
        return response
    except Exception:
        return {"error": "Reminder not found"}


def delete_reminder(user_id: str, reminder_id: str) -> dict:
    """Delete a reminder permanently.

    Args:
        user_id: The authenticated user's ID.
        reminder_id: The reminder ID to delete.

    Returns:
        Confirmation dict.
    """
    _reminders_repo.delete(user_id, reminder_id)
    return {"success": True, "deleted": reminder_id}
