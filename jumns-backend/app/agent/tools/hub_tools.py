"""Hub tools for Noor — conversation search, cross-agent summary, notifications.

Noor owns the /hub screen. These tools let her search past conversations,
generate cross-agent summaries, and manage the notification/briefing layer.
"""

from __future__ import annotations

from app.db.repositories.messages import MessagesRepository
from app.db.repositories.agent_context import AgentContextRepository
from app.memory.memory_service import MemoryService

_messages_repo = MessagesRepository()
_context_repo = AgentContextRepository()
_memory_service = MemoryService()


def search_conversations(user_id: str, query: str, limit: int) -> dict:
    """Search past conversation messages by keyword.

    Use when the user asks "what did we talk about...", "did I mention...",
    or needs to find something from a previous chat.

    Args:
        user_id: The authenticated user's ID.
        query: Search keyword or phrase.
        limit: Max results to return. Use 10 as a reasonable default.

    Returns:
        Matching messages with role, content preview, and timestamp.
    """
    actual_limit = limit if limit > 0 else 10
    messages = _messages_repo.list_messages(user_id)
    q = query.lower()
    matches = []
    for msg in reversed(messages):
        content = msg.get("content", "")
        if q in content.lower():
            matches.append({
                "role": msg.get("role", ""),
                "content": content[:200],
                "agent": msg.get("agent", ""),
                "createdAt": msg.get("createdAt", ""),
            })
            if len(matches) >= actual_limit:
                break

    return {
        "found": len(matches) > 0,
        "count": len(matches),
        "matches": matches,
    }


def get_cross_agent_summary(user_id: str) -> dict:
    """Get a summary of what all agents have been doing recently.

    Use for morning briefings, "catch me up", or when the user returns
    after being away. Reads the context bus to see Kai's planning,
    Echo's journaling, and Sage's goal analysis.

    Args:
        user_id: The authenticated user's ID.

    Returns:
        Summary organized by agent with recent activity.
    """
    all_events = _context_repo.get_recent(user_id, limit=30)

    by_agent: dict[str, list] = {"kai": [], "sage": [], "echo": [], "noor": []}
    for event in all_events:
        source = event.get("sourceAgent", "noor")
        if source in by_agent:
            by_agent[source].append({
                "event": event.get("eventType", ""),
                "summary": event.get("summary", ""),
                "createdAt": event.get("createdAt", ""),
            })

    sections = []
    agent_labels = {
        "kai": "Scheduling & Tasks",
        "sage": "Goals & Growth",
        "echo": "Journal & Memory",
        "noor": "Conversations",
    }
    for agent, events in by_agent.items():
        if events:
            sections.append({
                "agent": agent,
                "label": agent_labels.get(agent, agent),
                "recentActions": events[:5],
                "actionCount": len(events),
            })

    return {
        "sections": sections,
        "totalEvents": len(all_events),
        "hasActivity": len(all_events) > 0,
    }


def get_notification_digest(user_id: str) -> dict:
    """Get a digest of pending notifications and important updates.

    Checks context bus for unread agent events, memory bank for
    critical items, and recent messages for unanswered questions.

    Args:
        user_id: The authenticated user's ID.

    Returns:
        Notification digest with priority items.
    """
    # Recent context bus events (last 24h)
    recent_events = _context_repo.get_recent(user_id, limit=20)
    important_events = [
        e for e in recent_events
        if e.get("eventType") in (
            "goal_at_risk", "task_overdue", "journal_created",
            "goal_completed", "plan_created", "progress_report",
        )
    ]

    # Critical memories
    bank = _memory_service.get_memory_bank_summary(user_id)
    critical = bank.get("critical_memories", [])

    notifications = []
    for event in important_events[:5]:
        notifications.append({
            "type": event.get("eventType", ""),
            "source": event.get("sourceAgent", ""),
            "message": event.get("summary", ""),
            "priority": "high" if "risk" in event.get("eventType", "") or "overdue" in event.get("eventType", "") else "medium",
        })

    return {
        "notifications": notifications,
        "criticalMemories": len(critical),
        "totalPending": len(notifications),
        "memoryBankSize": bank.get("total_memories", 0),
    }
