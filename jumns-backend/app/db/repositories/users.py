"""Repository for users collection — Firestore.

Users are stored as top-level documents: users/{userId}
(not subcollections, since user is the root entity).
"""

from __future__ import annotations

from google.cloud import firestore

from app.db.base_repository import utc_now_iso
from app.db.connection import get_firestore_client
from app.db.table_config import USERS_COLLECTION


class UsersRepository:
    def __init__(self):
        self._db = get_firestore_client()
        self._collection = self._db.collection(USERS_COLLECTION)

    def _doc_ref(self, user_id: str) -> firestore.DocumentReference:
        return self._collection.document(user_id)

    def get_or_create_user(self, user_id: str) -> dict:
        doc = self._doc_ref(user_id).get()
        if doc.exists:
            return doc.to_dict()
        item = {
            "userId": user_id,
            "email": "",
            "timezone": "UTC",
            "agentName": "Jumns",
            "agentBehavior": "Friendly & Supportive",
            "onboardingCompleted": False,
            "morningTime": "07:00",
            "eveningTime": "21:00",
            "createdAt": utc_now_iso(),
        }
        self._doc_ref(user_id).set(item)
        return item

    def get_settings(self, user_id: str) -> dict:
        user = self.get_or_create_user(user_id)
        return {
            "agentName": user.get("agentName", "Jumns"),
            "agentBehavior": user.get("agentBehavior", "Friendly & Supportive"),
            "onboardingCompleted": user.get("onboardingCompleted", False),
            "timezone": user.get("timezone", "UTC"),
            "morningTime": user.get("morningTime", "07:00"),
            "eveningTime": user.get("eveningTime", "21:00"),
        }

    def upsert_settings(self, user_id: str, data: dict) -> dict:
        self.get_or_create_user(user_id)
        updates = {k: v for k, v in data.items() if v is not None}
        if updates:
            self._doc_ref(user_id).update(updates)
        return self.get_settings(user_id)

    def list_all_users(self, limit: int = 500) -> list[str]:
        """Return all user IDs from the top-level users collection."""
        try:
            docs = self._collection.select(["userId"]).limit(limit).stream()
            return [doc.id for doc in docs]
        except Exception:
            return []
