"""Shared context bus tools — given to ALL agents for cross-agent awareness.

Every agent gets these tools so they can:
- Read what other agents have done recently
- Publish significant actions for other agents to see
- Check if another agent already handled something
"""

from __future__ import annotations

from app.db.repositories.agent_context import AgentContextRepository

_context_repo = AgentContextRepository()


def read_agent_context(
    user_id: str,
    source_agent: str,
    limit: int,
) -> dict:
    """Read recent activity from other agents on the context bus.

    Use this to stay aware of what happened across the system.
    Check before duplicating work — if Kai already created tasks for
    a goal, don't create them again.

    Args:
        user_id: The authenticated user's ID.
        source_agent: Filter by agent name (noor, kai, sage, echo). Use empty string for all.
        limit: Max events to return. Use 10 as a reasonable default.

    Returns:
        Recent context events with source, type, and summary.
    """
    actual_limit = limit if limit > 0 else 10
    if source_agent:
        events = _context_repo.get_by_source(user_id, source_agent, limit=actual_limit)
    else:
        events = _context_repo.get_recent(user_id, limit=actual_limit)

    return {
        "events": [
            {
                "sourceAgent": e.get("sourceAgent", ""),
                "eventType": e.get("eventType", ""),
                "summary": e.get("summary", ""),
                "createdAt": e.get("createdAt", ""),
            }
            for e in events
        ],
        "count": len(events),
    }


def publish_context(
    user_id: str,
    event_type: str,
    summary: str,
    agent_name: str,
    target_agents: str,
) -> dict:
    """Publish a context event so other agents know what you did.

    ALWAYS publish after significant actions: creating goals, completing
    tasks, storing memories, generating plans, journal entries, etc.

    Args:
        user_id: The authenticated user's ID.
        event_type: Type of event (e.g. "task_created", "goal_completed",
                    "memory_stored", "plan_created", "journal_created").
        summary: Human-readable summary of what happened.
        agent_name: Your agent name (noor, kai, sage, echo). Use "noor" as default.
        target_agents: Comma-separated agent names, or "all". Use "all" as default.

    Returns:
        Confirmation dict.
    """
    targets = [t.strip() for t in target_agents.split(",") if t.strip()]

    _context_repo.publish(user_id, {
        "sourceAgent": agent_name or "noor",
        "eventType": event_type,
        "summary": summary,
        "targetAgents": targets,
    })

    return {"published": True, "eventType": event_type}
