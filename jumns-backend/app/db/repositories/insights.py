"""Repository for insights subcollection — Firestore."""

from __future__ import annotations

from app.db.base_repository import BaseRepository, new_id, utc_now_iso
from app.db.table_config import INSIGHTS_SUBCOLLECTION


class InsightsRepository(BaseRepository):
    def __init__(self):
        super().__init__(INSIGHTS_SUBCOLLECTION)

    def create(self, user_id: str, data: dict) -> dict:
        insight_id = new_id()
        now = utc_now_iso()
        item = {
            "userId": user_id,
            "insightId": insight_id,
            "id": insight_id,
            "type": data.get("type", "general"),
            "title": data.get("title", ""),
            "content": data.get("content", ""),
            "priority": data.get("priority", "medium"),
            "relatedGoalId": data.get("relatedGoalId"),
            "read": False,
            "dismissed": False,
            "createdAt": now,
        }
        item = {k: v for k, v in item.items() if v is not None}
        return self.put_item(user_id, insight_id, item)

    def list_all(self, user_id: str) -> list[dict]:
        return self.query_by_user(user_id, descending=True)

    def unread_count(self, user_id: str) -> int:
        items = self.query_by_user(user_id)
        return sum(1 for i in items if not i.get("read", False) and not i.get("dismissed", False))

    def mark_read(self, user_id: str, insight_id: str) -> dict:
        return self.update_item(user_id, insight_id, {"read": True})

    def dismiss(self, user_id: str, insight_id: str) -> dict:
        return self.update_item(user_id, insight_id, {"dismissed": True})
