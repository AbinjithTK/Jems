"""MCP connection manager — loads MCPToolset instances for ADK agents.

Validates user-provided MCP JSON configs, stores them in Firestore,
and dynamically loads MCPToolset instances into agent tool lists.
Built-in Notion MCP is auto-provisioned for every user.
"""

from __future__ import annotations

import json
import logging
from typing import Any

from app.db.repositories.mcp_servers import McpServersRepository

logger = logging.getLogger(__name__)

# Supported connection types and their required config fields
_REQUIRED_FIELDS = {
    "stdio": {"command"},
    "sse": {"url"},
    "streamable_http": {"url"},
}


class McpValidationError(Exception):
    """Raised when MCP server config JSON is invalid."""

    def __init__(self, errors: list[str]):
        self.errors = errors
        super().__init__("; ".join(errors))


class McpService:
    """Manages MCP server connections per user."""

    def __init__(self):
        self._repo = McpServersRepository()

    # ------------------------------------------------------------------
    # CRUD
    # ------------------------------------------------------------------

    def list_servers(self, user_id: str) -> list[dict]:
        """List all MCP servers for a user, ensuring built-in Notion exists."""
        self._repo.ensure_builtin_notion(user_id)
        return self._repo.list_servers(user_id)

    def add_server(self, user_id: str, raw_json: str) -> dict:
        """Parse, validate, and store a new MCP server config.

        Accepts raw JSON string (what the user pastes in the UI).
        """
        parsed = self._parse_json(raw_json)
        self._validate_config(parsed)
        return self._repo.create_server(user_id, parsed)

    def validate_config(self, raw_json: str) -> dict[str, Any]:
        """Validate MCP JSON without saving. Returns parsed config or raises."""
        parsed = self._parse_json(raw_json)
        self._validate_config(parsed)
        return {"valid": True, "parsed": parsed}

    def update_server(self, user_id: str, server_id: str, updates: dict) -> dict:
        return self._repo.update_server(user_id, server_id, updates)

    def delete_server(self, user_id: str, server_id: str) -> None:
        server = self._repo.get_server(user_id, server_id)
        if server.get("builtin"):
            raise ValueError("Cannot delete built-in MCP server")
        self._repo.delete_server(user_id, server_id)

    def toggle_server(self, user_id: str, server_id: str, enabled: bool) -> dict:
        return self._repo.update_server(user_id, server_id, {"enabled": enabled})

    def update_builtin_token(self, user_id: str, server_id: str, token: str) -> dict:
        """Update the auth token for a built-in MCP server (e.g. Notion).

        Stores the token inside config.env so it's passed as an environment
        variable when the stdio process is spawned.
        """
        server = self._repo.get_server(user_id, server_id)
        if not server:
            raise ValueError("Server not found")
        if not server.get("builtin"):
            raise ValueError("Token update is only supported for built-in servers")

        config = server.get("config", {})
        env = config.get("env", {})

        # Determine the correct env key based on server name
        if server.get("name") == "Notion":
            env["NOTION_TOKEN"] = token
        else:
            env["TOKEN"] = token

        config["env"] = env
        return self._repo.update_server(user_id, server_id, {"config": config})

    # ------------------------------------------------------------------
    # ADK integration — load MCPToolset instances for agent building
    # ------------------------------------------------------------------

    async def load_toolsets(self, user_id: str) -> list:
        """Load MCPToolset instances for all enabled MCP servers.

        Returns a list of ADK-compatible toolset objects that can be
        added to an agent's tools list.
        """
        servers = self.list_servers(user_id)
        toolsets = []

        for server in servers:
            if not server.get("enabled", True):
                continue

            config = server.get("config", {})
            conn_type = server.get("connectionType", "stdio")

            try:
                toolset = await self._create_toolset(conn_type, config)
                if toolset:
                    toolsets.append(toolset)
                    logger.info(
                        "Loaded MCP toolset: %s for user %s",
                        server.get("name"), user_id,
                    )
            except Exception:
                logger.warning(
                    "Failed to load MCP server %s for user %s",
                    server.get("name"), user_id,
                    exc_info=True,
                )

        return toolsets

    async def _create_toolset(self, conn_type: str, config: dict):
        """Create an ADK MCPToolset from a stored config."""
        try:
            from google.adk.tools.mcp_tool.mcp_toolset import MCPToolset
        except ImportError:
            logger.warning("google-adk MCP support not available")
            return None

        if conn_type == "stdio":
            from mcp import StdioServerParameters

            # Skip if required env token is empty (e.g. unconfigured Notion)
            env = config.get("env") or {}
            for key in ("NOTION_TOKEN", "TOKEN"):
                if key in env and not env[key]:
                    logger.info("Skipping MCP server — %s is empty", key)
                    return None

            params = StdioServerParameters(
                command=config["command"],
                args=config.get("args", []),
                env=config.get("env"),
            )
            return MCPToolset(connection_params=params)

        if conn_type == "sse":
            from google.adk.tools.mcp_tool.mcp_toolset import SseServerParams

            return MCPToolset(
                connection_params=SseServerParams(url=config["url"]),
            )

        if conn_type == "streamable_http":
            from google.adk.tools.mcp_tool.mcp_toolset import (
                StreamableHTTPConnectionParams,
            )

            return MCPToolset(
                connection_params=StreamableHTTPConnectionParams(
                    url=config["url"],
                ),
            )

        return None

    # ------------------------------------------------------------------
    # Validation helpers
    # ------------------------------------------------------------------

    def _parse_json(self, raw_json: str) -> dict:
        """Parse raw JSON string into a config dict."""
        try:
            data = json.loads(raw_json)
        except json.JSONDecodeError as exc:
            raise McpValidationError([f"Invalid JSON: {exc.msg}"]) from exc

        if not isinstance(data, dict):
            raise McpValidationError(["Config must be a JSON object"])
        return data

    def _validate_config(self, config: dict) -> None:
        """Validate parsed MCP config structure."""
        errors: list[str] = []

        if "name" not in config:
            errors.append("Missing required field: 'name'")

        if "config" not in config and "command" not in config and "url" not in config:
            errors.append("Missing connection config: need 'config', 'command', or 'url'")

        # Normalize: if user provides flat config (command/url at top level)
        inner = config.get("config", config)
        conn_type = config.get("connectionType", "stdio")

        if "url" in inner and conn_type == "stdio":
            config["connectionType"] = "sse"
            conn_type = "sse"

        required = _REQUIRED_FIELDS.get(conn_type, set())
        for field in required:
            if field not in inner:
                errors.append(f"Missing required field for {conn_type}: '{field}'")

        if errors:
            raise McpValidationError(errors)

        # Ensure nested config structure
        if "config" not in config:
            config["config"] = {
                k: v for k, v in config.items()
                if k not in ("name", "description", "connectionType", "builtin")
            }
