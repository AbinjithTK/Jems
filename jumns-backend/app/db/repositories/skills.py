"""Repository for skills subcollection — Firestore."""

from __future__ import annotations

from app.db.base_repository import BaseRepository, new_id, utc_now_iso
from app.db.table_config import SKILLS_SUBCOLLECTION


class SkillsRepository(BaseRepository):
    def __init__(self):
        super().__init__(SKILLS_SUBCOLLECTION)

    def create(self, user_id: str, data: dict) -> dict:
        skill_id = new_id()
        item = {
            "userId": user_id,
            "skillId": skill_id,
            "id": skill_id,
            "name": data["name"],
            "type": data.get("type", "mcp"),
            "description": data.get("description", ""),
            "status": data.get("status", "inactive"),
            "category": data.get("category", "mcp"),
            "createdAt": utc_now_iso(),
        }
        return self.put_item(user_id, skill_id, item)

    def get(self, user_id: str, skill_id: str) -> dict:
        return self.get_item(user_id, skill_id)

    def list_all(self, user_id: str) -> list[dict]:
        return self.query_by_user(user_id)

    def update(self, user_id: str, skill_id: str, data: dict) -> dict:
        updates = {k: v for k, v in data.items() if v is not None}
        return self.update_item(user_id, skill_id, updates)

    def delete(self, user_id: str, skill_id: str) -> None:
        self.delete_item(user_id, skill_id)
