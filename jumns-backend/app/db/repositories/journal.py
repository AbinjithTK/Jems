"""Repository for journal subcollection — Firestore (Echo's journal entries)."""

from __future__ import annotations

from app.db.base_repository import BaseRepository, new_id, utc_now_iso
from app.db.table_config import JOURNAL_SUBCOLLECTION


class JournalRepository(BaseRepository):
    def __init__(self):
        super().__init__(JOURNAL_SUBCOLLECTION)

    def create(self, user_id: str, data: dict) -> dict:
        entry_id = new_id()
        now = utc_now_iso()
        item = {
            "userId": user_id,
            "entryId": entry_id,
            "id": entry_id,
            "type": data.get("type", "thought"),
            "content": data.get("content", ""),
            "title": data.get("title", ""),
            "mood": data.get("mood"),
            "tags": data.get("tags", []),
            "mediaUrl": data.get("mediaUrl"),
            "shareable": data.get("shareable", False),
            "draft": data.get("draft", True),
            "agentPrompted": data.get("agentPrompted", False),
            "linkedGoalId": data.get("linkedGoalId"),
            "createdAt": now,
        }
        item = {k: v for k, v in item.items() if v is not None}
        return self.put_item(user_id, entry_id, item)

    def list_all(self, user_id: str, entry_type: str | None = None) -> list[dict]:
        filters = [("type", "==", entry_type)] if entry_type else None
        return self.query_by_user(user_id, descending=True, filters=filters)

    def get(self, user_id: str, entry_id: str) -> dict:
        return self.get_item(user_id, entry_id)

    def update(self, user_id: str, entry_id: str, updates: dict) -> dict:
        updates = {k: v for k, v in updates.items() if v is not None}
        return self.update_item(user_id, entry_id, updates)

    def delete(self, user_id: str, entry_id: str) -> None:
        self.delete_item(user_id, entry_id)
