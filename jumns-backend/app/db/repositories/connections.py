"""Repository for connections subcollection — Firestore (A2A social connections)."""

from __future__ import annotations

from app.db.base_repository import BaseRepository, new_id, utc_now_iso
from app.db.table_config import CONNECTIONS_SUBCOLLECTION


class ConnectionsRepository(BaseRepository):
    def __init__(self):
        super().__init__(CONNECTIONS_SUBCOLLECTION)

    def create_connection(self, user_id: str, data: dict) -> dict:
        """Create a new social connection (friend request)."""
        connection_id = new_id()
        item = {
            "userId": user_id,
            "connectionId": connection_id,
            "id": connection_id,
            "friendUserId": data["friendUserId"],
            "friendDisplayName": data.get("friendDisplayName", ""),
            "friendAgentCardUrl": data.get("friendAgentCardUrl", ""),
            "status": "pending",
            "initiatedBy": user_id,
            "createdAt": utc_now_iso(),
            "updatedAt": utc_now_iso(),
        }
        return self.put_item(user_id, connection_id, item)

    def list_connections(self, user_id: str, status: str | None = None) -> list[dict]:
        """List all connections, optionally filtered by status."""
        filters = [("status", "==", status)] if status else None
        return self.query_by_user(user_id, filters=filters)

    def get_connection(self, user_id: str, connection_id: str) -> dict:
        return self.get_item(user_id, connection_id)

    def update_status(self, user_id: str, connection_id: str, status: str) -> dict:
        return self.update_item(user_id, connection_id, {
            "status": status,
            "updatedAt": utc_now_iso(),
        })

    def delete_connection(self, user_id: str, connection_id: str) -> None:
        self.delete_item(user_id, connection_id)
