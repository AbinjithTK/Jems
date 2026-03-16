"""Repository for messages subcollection — Firestore."""

from __future__ import annotations

from app.db.base_repository import BaseRepository, new_id, utc_now_iso
from app.db.table_config import MESSAGES_SUBCOLLECTION


class MessagesRepository(BaseRepository):
    def __init__(self):
        super().__init__(MESSAGES_SUBCOLLECTION)

    def create_message(self, user_id: str, data: dict) -> dict:
        msg_id = new_id()
        now = utc_now_iso()
        item = {
            "userId": user_id,
            "id": msg_id,
            "role": data.get("role", "user"),
            "type": data.get("type", "text"),
            "content": data.get("content"),
            "cardType": data.get("cardType"),
            "cardData": data.get("cardData"),
            "agent": data.get("agent"),
            "delegatedTo": data.get("delegatedTo"),
            "timestamp": now,
            "createdAt": now,
        }
        item = {k: v for k, v in item.items() if v is not None}
        return self.put_item(user_id, msg_id, item)

    def list_messages(self, user_id: str) -> list[dict]:
        return self.query_by_user(user_id, order_by="createdAt", descending=False)

    def count_user_messages_today(self, user_id: str, date_prefix: str) -> int:
        """Count user-role messages sent today (for rate limiting)."""
        try:
            items = self.query_by_user(
                user_id,
                filters=[("role", "==", "user")],
            )
            return sum(1 for m in items if m.get("createdAt", "").startswith(date_prefix))
        except Exception:
            return 0

    def delete_all_messages(self, user_id: str) -> None:
        items = self.query_by_user(user_id)
        doc_ids = [item["id"] for item in items if "id" in item]
        if doc_ids:
            self.batch_delete(user_id, doc_ids)
