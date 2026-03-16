"""Repository for agent_context subcollection — Firestore.

Inter-agent shared context bus. Agents write context entries when they
perform significant actions. Other agents read these to stay aware.
Entries should auto-expire after 24h (configure Firestore TTL policy
on the 'expireAt' field).
"""

from __future__ import annotations

from datetime import datetime, timezone, timedelta

from app.db.base_repository import BaseRepository, new_id, utc_now_iso
from app.db.table_config import AGENT_CONTEXT_SUBCOLLECTION


class AgentContextRepository(BaseRepository):
    def __init__(self):
        super().__init__(AGENT_CONTEXT_SUBCOLLECTION)

    def publish(self, user_id: str, data: dict) -> dict:
        """Publish a context event from one agent for others to read."""
        ctx_id = new_id()
        now = utc_now_iso()
        item = {
            "userId": user_id,
            "ctxId": ctx_id,
            "id": ctx_id,
            "sourceAgent": data.get("sourceAgent", "noor"),
            "eventType": data.get("eventType", "action"),
            "summary": data.get("summary", ""),
            "details": data.get("details", {}),
            "targetAgents": data.get("targetAgents", ["all"]),
            "createdAt": now,
            "expireAt": (datetime.now(timezone.utc) + timedelta(hours=24)).isoformat(),
        }
        item = {k: v for k, v in item.items() if v is not None}
        return self.put_item(user_id, ctx_id, item)

    def get_recent(
        self, user_id: str, agent_name: str | None = None, limit: int = 20,
    ) -> list[dict]:
        """Get recent context events, optionally filtered for a specific agent."""
        items = self.query_by_user(user_id, descending=True, limit=limit)
        if agent_name:
            items = [
                i for i in items
                if "all" in i.get("targetAgents", [])
                or agent_name in i.get("targetAgents", [])
            ]
        return items

    def get_by_source(self, user_id: str, source_agent: str, limit: int = 10) -> list[dict]:
        """Get recent events published by a specific agent."""
        items = self.query_by_user(
            user_id,
            descending=True,
            limit=50,
            filters=[("sourceAgent", "==", source_agent)],
        )
        return items[:limit]
