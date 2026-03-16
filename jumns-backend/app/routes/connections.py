"""Connections endpoints — MCP servers + A2A social connections + friend messaging."""

from __future__ import annotations

import logging

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from app.connections.a2a_service import A2aService
from app.connections.mcp_service import McpService, McpValidationError
from app.db.repositories.friend_messages import FriendMessagesRepository
from app.models.requests import CreateFriendMessageRequest
from app.models.responses import FriendMessageResponse

logger = logging.getLogger(__name__)

router = APIRouter(tags=["connections"])

_friend_msg_repo = FriendMessagesRepository()


# ---------------------------------------------------------------------------
# Request models
# ---------------------------------------------------------------------------

class FriendRequestBody(BaseModel):
    friendUserId: str
    friendDisplayName: str = ""
    agentCardUrl: str = ""


class McpServerBody(BaseModel):
    raw_json: str


class McpToggleBody(BaseModel):
    enabled: bool


class McpTokenBody(BaseModel):
    token: str


# ---------------------------------------------------------------------------
# A2A Social Connections
# ---------------------------------------------------------------------------

@router.get("/connections")
async def list_connections(request: Request):
    user_id = request.state.user_id
    status = request.query_params.get("status")
    svc = A2aService()
    connections = svc.list_connections(user_id, status=status)
    return {"connections": connections}


@router.post("/connections/request")
async def send_friend_request(request: Request, body: FriendRequestBody):
    user_id = request.state.user_id
    svc = A2aService()
    conn = svc.send_request(user_id, body.model_dump())
    return {"connection": conn}


@router.post("/connections/{connection_id}/accept")
async def accept_connection(request: Request, connection_id: str):
    user_id = request.state.user_id
    svc = A2aService()
    try:
        conn = svc.accept_request(user_id, connection_id)
        return {"connection": conn}
    except ValueError as exc:
        return JSONResponse(status_code=400, content={"error": str(exc)})


@router.post("/connections/{connection_id}/reject")
async def reject_connection(request: Request, connection_id: str):
    user_id = request.state.user_id
    svc = A2aService()
    conn = svc.reject_request(user_id, connection_id)
    return {"connection": conn}


@router.delete("/connections/{connection_id}")
async def delete_connection(request: Request, connection_id: str):
    user_id = request.state.user_id
    svc = A2aService()
    svc.remove_connection(user_id, connection_id)
    return JSONResponse(status_code=204, content=None)


@router.get("/connections/agent-card")
async def get_my_agent_card(request: Request):
    """Return this user's A2A agent card URL for sharing with friends."""
    user_id = request.state.user_id
    svc = A2aService()
    return {"agentCardUrl": svc.get_agent_card_url(user_id)}


# ---------------------------------------------------------------------------
# MCP Server Management
# ---------------------------------------------------------------------------

@router.get("/mcp/servers")
async def list_mcp_servers(request: Request):
    user_id = request.state.user_id
    svc = McpService()
    servers = svc.list_servers(user_id)
    return {"servers": servers}


@router.post("/mcp/servers")
async def add_mcp_server(request: Request, body: McpServerBody):
    """Add a new MCP server — user pastes raw JSON config."""
    user_id = request.state.user_id
    svc = McpService()
    try:
        server = svc.add_server(user_id, body.raw_json)
        return {"server": server}
    except McpValidationError as exc:
        return JSONResponse(
            status_code=422,
            content={"error": "Invalid MCP config", "details": exc.errors},
        )


@router.post("/mcp/servers/validate")
async def validate_mcp_config(body: McpServerBody):
    """Validate MCP JSON config without saving."""
    svc = McpService()
    try:
        result = svc.validate_config(body.raw_json)
        return result
    except McpValidationError as exc:
        return JSONResponse(
            status_code=422,
            content={"valid": False, "errors": exc.errors},
        )


@router.post("/mcp/servers/{server_id}/toggle")
async def toggle_mcp_server(request: Request, server_id: str, body: McpToggleBody):
    user_id = request.state.user_id
    svc = McpService()
    server = svc.toggle_server(user_id, server_id, body.enabled)
    return {"server": server}


@router.post("/mcp/servers/{server_id}/token")
async def update_mcp_server_token(request: Request, server_id: str, body: McpTokenBody):
    """Update the auth token for a built-in MCP server (e.g. Notion)."""
    user_id = request.state.user_id
    svc = McpService()
    try:
        server = svc.update_builtin_token(user_id, server_id, body.token)
        return {"server": server}
    except ValueError as exc:
        return JSONResponse(status_code=400, content={"error": str(exc)})


@router.delete("/mcp/servers/{server_id}")
async def delete_mcp_server(request: Request, server_id: str):
    user_id = request.state.user_id
    svc = McpService()
    try:
        svc.delete_server(user_id, server_id)
        return JSONResponse(status_code=204, content=None)
    except ValueError as exc:
        return JSONResponse(status_code=400, content={"error": str(exc)})


# ---------------------------------------------------------------------------
# Friend Messaging (DMs between connected friends)
# ---------------------------------------------------------------------------

@router.get("/connections/{connection_id}/messages")
async def list_friend_messages(request: Request, connection_id: str):
    user_id = request.state.user_id
    limit = int(request.query_params.get("limit", "50"))
    messages = _friend_msg_repo.list_by_connection(user_id, connection_id, limit=limit)
    return {
        "messages": [
            FriendMessageResponse(**m).model_dump(by_alias=True) for m in messages
        ]
    }


@router.post("/connections/{connection_id}/messages")
async def send_friend_message(
    request: Request, connection_id: str, body: CreateFriendMessageRequest
):
    user_id = request.state.user_id
    msg = _friend_msg_repo.create(
        user_id,
        {
            "connectionId": connection_id,
            "friendUserId": body.friend_user_id,
            "senderUserId": user_id,
            "content": body.content,
            "type": body.type,
        },
    )
    return {
        "message": FriendMessageResponse(**msg).model_dump(by_alias=True)
    }


@router.delete("/connections/{connection_id}/messages/{message_id}")
async def delete_friend_message(
    request: Request, connection_id: str, message_id: str
):
    user_id = request.state.user_id
    _friend_msg_repo.delete(user_id, message_id)
    return JSONResponse(status_code=204, content=None)
