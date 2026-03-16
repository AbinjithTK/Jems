"""Repository for mcp_servers subcollection — Firestore."""

from __future__ import annotations

from app.db.base_repository import BaseRepository, new_id, utc_now_iso
from app.db.table_config import MCP_SERVERS_SUBCOLLECTION


class McpServersRepository(BaseRepository):
    def __init__(self):
        super().__init__(MCP_SERVERS_SUBCOLLECTION)

    def create_server(self, user_id: str, data: dict) -> dict:
        """Store a new MCP server config for a user."""
        server_id = new_id()
        item = {
            "userId": user_id,
            "serverId": server_id,
            "id": server_id,
            "name": data["name"],
            "description": data.get("description", ""),
            "connectionType": data.get("connectionType", "stdio"),
            "config": data["config"],
            "enabled": True,
            "builtin": data.get("builtin", False),
            "createdAt": utc_now_iso(),
            "updatedAt": utc_now_iso(),
        }
        return self.put_item(user_id, server_id, item)

    def list_servers(self, user_id: str) -> list[dict]:
        return self.query_by_user(user_id)

    def get_server(self, user_id: str, server_id: str) -> dict:
        return self.get_item(user_id, server_id)

    def update_server(self, user_id: str, server_id: str, updates: dict) -> dict:
        updates["updatedAt"] = utc_now_iso()
        return self.update_item(user_id, server_id, updates)

    def delete_server(self, user_id: str, server_id: str) -> None:
        self.delete_item(user_id, server_id)

    def ensure_builtin_notion(self, user_id: str) -> dict | None:
        """Ensure the built-in Notion MCP server exists for the user."""
        servers = self.list_servers(user_id)
        for s in servers:
            if s.get("builtin") and s.get("name") == "Notion":
                return s
        return self.create_server(user_id, {
            "name": "Notion",
            "description": "Connect your Notion workspace to let agents read and manage your pages, databases, and more.",
            "connectionType": "stdio",
            "config": {
                "command": "npx",
                "args": ["-y", "@notionhq/notion-mcp-server"],
                "env": {"NOTION_TOKEN": ""},
            },
            "builtin": True,
        })
