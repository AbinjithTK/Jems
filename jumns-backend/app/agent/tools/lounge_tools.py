"""Lounge/social tools for Sage — social briefing, friend activity, peer updates.

Sage owns the /lounge screen. These tools let it generate social briefings,
view friend activity feeds, and manage the social layer of the app.
Also includes inter-agent context reading so Sage can see what Kai/Echo did.
"""

from __future__ import annotations

from app.db.repositories.connections import ConnectionsRepository
from app.db.repositories.agent_context import AgentContextRepository
from app.db.repositories.goals import GoalsRepository

_connections_repo = ConnectionsRepository()
_context_repo = AgentContextRepository()
_goals_repo = GoalsRepository()


def get_social_feed(user_id: str, limit: int) -> dict:
    """Get the social activity feed for the lounge screen.

    Shows friend connections, their shared updates, and social context.
    This is the primary data source for the /lounge social briefing room.

    Args:
        user_id: The authenticated user's ID.
        limit: Max items to return. Use 10 as a reasonable default.

    Returns:
        Social feed with friend activity and connection stats.
    """
    actual_limit = limit if limit > 0 else 10
    connections = _connections_repo.list_connections(user_id)
    accepted = [c for c in connections if c.get("status") == "accepted"]
    pending = [c for c in connections if c.get("status") == "pending"]

    friend_summaries = []
    for conn in accepted[:actual_limit]:
        friend_summaries.append({
            "connectionId": conn.get("connectionId", ""),
            "displayName": conn.get("friendDisplayName", "Friend"),
            "hasAgentCard": bool(conn.get("friendAgentCardUrl")),
            "connectedSince": conn.get("createdAt", ""),
        })

    return {
        "totalFriends": len(accepted),
        "pendingRequests": len(pending),
        "friends": friend_summaries,
        "pendingDetails": [
            {
                "connectionId": c.get("connectionId", ""),
                "displayName": c.get("friendDisplayName", ""),
                "initiatedBy": c.get("initiatedBy", ""),
            }
            for c in pending[:5]
        ],
    }


def generate_social_briefing(user_id: str) -> dict:
    """Generate a social briefing card for the lounge screen.

    Combines friend activity, shared goal progress, and social context
    into a briefing that Sage presents conversationally.

    Args:
        user_id: The authenticated user's ID.

    Returns:
        Social briefing with sections for friends, shared goals, and suggestions.
    """
    connections = _connections_repo.list_connections(user_id, status="accepted")
    goals = _goals_repo.list_all(user_id)
    active_goals = [g for g in goals if not g.get("completed")]

    # Check what other agents have been doing (context bus)
    recent_context = _context_repo.get_recent(user_id, agent_name="sage", limit=15)
    agent_activity = []
    for ctx in recent_context:
        if ctx.get("sourceAgent") != "sage":
            agent_activity.append({
                "agent": ctx.get("sourceAgent", ""),
                "event": ctx.get("eventType", ""),
                "summary": ctx.get("summary", ""),
            })

    briefing_sections = []

    # Friend section
    if connections:
        briefing_sections.append({
            "title": "Your Circle",
            "type": "friends",
            "content": f"You have {len(connections)} connected friends.",
            "items": [c.get("friendDisplayName", "Friend") for c in connections[:5]],
        })

    # Goal sharing opportunities
    shareable_goals = [
        g for g in active_goals
        if g.get("progress", 0) > 0 and g.get("total", 100) > 0
        and (g["progress"] / g["total"]) > 0.5
    ]
    if shareable_goals:
        briefing_sections.append({
            "title": "Worth Sharing",
            "type": "achievements",
            "content": "Goals you're crushing that friends might want to hear about.",
            "items": [
                f"{g.get('title', '')} — {round((g['progress'] / g['total']) * 100)}%"
                for g in shareable_goals[:3]
            ],
        })

    # Cross-agent activity
    if agent_activity:
        briefing_sections.append({
            "title": "What's Been Happening",
            "type": "activity",
            "content": "Recent activity from your other agents.",
            "items": [a["summary"] for a in agent_activity[:5]],
        })

    return {
        "briefing": briefing_sections,
        "friendCount": len(connections),
        "hasPendingRequests": bool(
            _connections_repo.list_connections(user_id, status="pending")
        ),
    }


def get_agent_activity(user_id: str, agent_name: str, limit: int) -> dict:
    """Read the inter-agent context bus to see what other agents have done.

    Sage uses this to stay aware of Kai's planning, Echo's journaling,
    and Noor's conversations — enabling cross-agent insights.

    Args:
        user_id: The authenticated user's ID.
        agent_name: Filter by source agent (noor, kai, echo). Use empty string for all.
        limit: Max events to return. Use 10 as a reasonable default.

    Returns:
        Recent agent activity events.
    """
    actual_limit = limit if limit > 0 else 10
    if agent_name:
        events = _context_repo.get_by_source(user_id, agent_name, limit=actual_limit)
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
        "totalEvents": len(events),
    }


def publish_agent_event(
    user_id: str,
    event_type: str,
    summary: str,
    target_agents: str,
) -> dict:
    """Publish an event to the inter-agent context bus.

    Use this when Sage performs a significant action that other agents
    should know about (goal analysis, progress reports, social updates).

    Args:
        user_id: The authenticated user's ID.
        event_type: Type of event (e.g. "goal_analyzed", "progress_report", "social_update").
        summary: Human-readable summary of what happened.
        target_agents: Comma-separated agent names, or "all". Use "all" as default.

    Returns:
        Confirmation dict.
    """
    targets = [t.strip() for t in target_agents.split(",") if t.strip()]

    _context_repo.publish(user_id, {
        "sourceAgent": "sage",
        "eventType": event_type,
        "summary": summary,
        "targetAgents": targets,
    })

    return {"published": True, "eventType": event_type, "targets": targets}
