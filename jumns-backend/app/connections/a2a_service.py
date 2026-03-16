"""A2A social connections — friend agent discovery and RemoteA2aAgent loading.

Manages friend requests, agent card exchange, and instantiation of
RemoteA2aAgent for friend agents that get added as sub_agents to Noor.
"""

from __future__ import annotations

import logging
from typing import Any

from app.db.repositories.connections import ConnectionsRepository

logger = logging.getLogger(__name__)


class A2aService:
    """Manages A2A social connections between users' agents."""

    def __init__(self):
        self._repo = ConnectionsRepository()

    # ------------------------------------------------------------------
    # Friend request lifecycle
    # ------------------------------------------------------------------

    def send_request(self, user_id: str, data: dict) -> dict:
        """Send a friend/agent connection request."""
        return self._repo.create_connection(user_id, {
            "friendUserId": data["friendUserId"],
            "friendDisplayName": data.get("friendDisplayName", ""),
            "friendAgentCardUrl": data.get("agentCardUrl", ""),
        })

    def accept_request(self, user_id: str, connection_id: str) -> dict:
        """Accept a pending friend request."""
        conn = self._repo.get_connection(user_id, connection_id)
        if conn.get("status") != "pending":
            raise ValueError(f"Connection is not pending: {conn.get('status')}")
        return self._repo.update_status(user_id, connection_id, "accepted")

    def reject_request(self, user_id: str, connection_id: str) -> dict:
        return self._repo.update_status(user_id, connection_id, "rejected")

    def block_connection(self, user_id: str, connection_id: str) -> dict:
        return self._repo.update_status(user_id, connection_id, "blocked")

    def remove_connection(self, user_id: str, connection_id: str) -> None:
        self._repo.delete_connection(user_id, connection_id)

    def list_connections(self, user_id: str, status: str | None = None) -> list[dict]:
        return self._repo.list_connections(user_id, status=status)

    def get_connection(self, user_id: str, connection_id: str) -> dict:
        return self._repo.get_connection(user_id, connection_id)

    # ------------------------------------------------------------------
    # A2A agent loading — creates RemoteA2aAgent for accepted friends
    # ------------------------------------------------------------------

    def load_friend_agents(self, user_id: str) -> list[Any]:
        """Load RemoteA2aAgent instances for all accepted friend connections.

        These get added as sub_agents to the root Noor agent so the user
        can ask Noor to interact with friends' agents.
        """
        try:
            from google.adk.agents.remote_a2a_agent import RemoteA2aAgent
        except ImportError:
            logger.debug("RemoteA2aAgent not available — skipping friend agents")
            return []

        connections = self._repo.list_connections(user_id, status="accepted")
        agents = []

        for conn in connections:
            card_url = conn.get("friendAgentCardUrl", "")
            if not card_url:
                continue

            friend_name = conn.get("friendDisplayName", "friend")
            safe_name = _sanitize_agent_name(friend_name)

            try:
                agent = RemoteA2aAgent(
                    name=f"friend_{safe_name}",
                    description=(
                        f"Social agent for your friend {friend_name}. "
                        f"You can ask this agent about {friend_name}'s shared updates, "
                        f"coordinate plans, or send messages."
                    ),
                    agent_card=card_url,
                )
                agents.append(agent)
                logger.info("Loaded friend agent: %s (%s)", safe_name, card_url)
            except Exception:
                logger.warning(
                    "Failed to load friend agent %s at %s",
                    friend_name, card_url,
                    exc_info=True,
                )

        return agents

    # ------------------------------------------------------------------
    # Agent card generation — expose this user's agent via A2A
    # ------------------------------------------------------------------

    def get_agent_card_url(self, user_id: str) -> str:
        """Return the A2A agent card URL for this user's Noor agent.

        In production this would be a public URL. For now, returns
        a placeholder that the user can share with friends.
        """
        import os
        base = os.getenv("JUMNS_A2A_BASE_URL", "https://api.jumns.app")
        return f"{base}/a2a/{user_id}/.well-known/agent-card.json"


def _sanitize_agent_name(name: str) -> str:
    """Convert a display name to a valid ADK agent name."""
    safe = "".join(c if c.isalnum() else "_" for c in name.lower())
    return safe[:32] or "unknown"
