"""Repository for friend_messages subcollection — Firestore DMs between friends."""

from __future__ import annotations

from app.db.base_repository import BaseRepository, new_id, utc_now_iso
from app.db.table_config import FRIEND_MESSAGES_SUBCOLLECTION


class FriendMessagesRepository(BaseRepository):
    def __init__(self):
        super().__init__(FRIEND_MESSAGES_SUBCOLLECTION)

    def create(self, user_id: str, data: dict) -> dict:
        msg_id = new_id()
        now = utc_now_iso()
        item = {
            "id": msg_id,
            "messageId": msg_id,
            "userId": user_id,
            "connectionId": data["connectionId"],
            "friendUserId": data["friendUserId"],
            "senderUserId": data["senderUserId"],
            "content": data.get("content", ""),
            "type": data.get("type", "text"),
            "createdAt": now,
        }
        item = {k: v for k, v in item.items() if v is not None}
        return self.put_item(user_id, msg_id, item)

    def list_by_connection(
        self, user_id: str, connection_id: str, limit: int = 50
    ) -> list[dict]:
        return self.query_by_user(
            user_id,
            filters=[("connectionId", "==", connection_id)],
            descending=False,
            limit=limit,
        )

    def get(self, user_id: str, message_id: str) -> dict:
        return self.get_item(user_id, message_id)

    def delete(self, user_id: str, message_id: str) -> None:
        self.delete_item(user_id, message_id)
