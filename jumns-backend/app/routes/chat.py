"""Chat endpoints — REST + bidi-streaming WebSocket + agent listing."""

from __future__ import annotations

import asyncio
import json
import logging

from fastapi import APIRouter, Request, WebSocket, WebSocketDisconnect

from app.agent.agent_service import AgentService
from app.db.base_repository import new_id, utc_now_iso
from app.middleware.rate_limiter import check_rate_limit
from app.models.requests import ChatRequest
from app.models.responses import AgentChatResponse, AgentInfoResponse

logger = logging.getLogger(__name__)

router = APIRouter(tags=["chat"])

VALID_AGENTS = {"noor", "kai", "sage", "echo"}

AGENT_INFO = [
    {
        "name": "noor",
        "displayName": "Noor",
        "description": "Your main conversational partner. Warm, curious, and slightly witty.",
        "role": "Main agent — orchestrates and delegates",
        "tab": "/hub",
        "accent": "#10B981",
        "icon": "chat_bubble",
    },
    {
        "name": "kai",
        "displayName": "Kai",
        "description": "Your scheduler. Organized, calm, and nerdy about productivity.",
        "role": "Tasks, reminders, calendar, and planning",
        "tab": "/schedule",
        "accent": "#FACC15",
        "icon": "calendar_today",
    },
    {
        "name": "sage",
        "displayName": "Sage",
        "description": "Your growth partner. Thoughtful, philosophical, but practical.",
        "role": "Goals, progress analysis, and insights",
        "tab": "/lounge",
        "accent": "#F472B6",
        "icon": "flag",
    },
    {
        "name": "echo",
        "displayName": "Echo",
        "description": "Your memory keeper. Quiet, observant, deeply empathetic.",
        "role": "Memories, journaling, and reflection",
        "tab": "/journal",
        "accent": "#A78BFA",
        "icon": "waves",
    },
]


# ---------------------------------------------------------------------------
# REST endpoints (existing)
# ---------------------------------------------------------------------------

@router.post("/chat")
async def chat(request: Request, body: ChatRequest) -> AgentChatResponse:
    """Send a message to Noor (main agent with delegation)."""
    user_id = request.state.user_id
    await check_rate_limit(user_id)

    agent = AgentService()
    result = await agent.invoke(user_id, body.message, agent_name="noor")

    now = utc_now_iso()
    return AgentChatResponse(
        id=new_id(),
        user_id=user_id,
        role="assistant",
        type="card" if result.get("cardType") else "text",
        content=result.get("content", ""),
        card_type=result.get("cardType"),
        card_data=result.get("cardData"),
        agent=result.get("agent", "noor"),
        delegated_to=result.get("delegatedTo"),
        navigation=result.get("navigation"),
        timestamp=now,
        created_at=now,
    )


@router.post("/chat/agent/{agent_name}")
async def chat_agent(
    request: Request, agent_name: str, body: ChatRequest,
) -> AgentChatResponse:
    """Send a message directly to a specific agent (from their tab)."""
    user_id = request.state.user_id

    if agent_name not in VALID_AGENTS:
        from fastapi.responses import JSONResponse
        return JSONResponse(
            status_code=400,
            content={"error": f"Unknown agent: {agent_name}. Valid: {', '.join(VALID_AGENTS)}"},
        )

    await check_rate_limit(user_id)

    agent = AgentService()
    result = await agent.invoke(user_id, body.message, agent_name=agent_name)

    now = utc_now_iso()
    return AgentChatResponse(
        id=new_id(),
        user_id=user_id,
        role="assistant",
        type="card" if result.get("cardType") else "text",
        content=result.get("content", ""),
        card_type=result.get("cardType"),
        card_data=result.get("cardData"),
        agent=result.get("agent", agent_name),
        delegated_to=result.get("delegatedTo"),
        navigation=result.get("navigation"),
        timestamp=now,
        created_at=now,
    )


@router.get("/agents")
async def list_agents() -> list[AgentInfoResponse]:
    """List available agents with their names, descriptions, and visual identity."""
    return [AgentInfoResponse(**info) for info in AGENT_INFO]


# ---------------------------------------------------------------------------
# Bidi-streaming WebSocket endpoint
# ---------------------------------------------------------------------------

@router.websocket("/ws/chat/{user_id}/{session_id}")
async def websocket_chat(
    websocket: WebSocket,
    user_id: str,
    session_id: str,
):
    """Bidi-streaming WebSocket endpoint using ADK Runner.run_live().

    Protocol:
    - Client sends JSON: {"type": "text", "text": "..."} or
                         {"type": "audio", "data": "<base64>", "mimeType": "audio/pcm"}
    - Server sends JSON events: {"type": "event", "text": "...", "author": "noor"}
                                {"type": "turn_complete", "author": "noor"}
                                {"type": "tool_call", "calls": [...]}
                                {"type": "error", "error": "..."}
    - Client sends {"type": "close"} to end session gracefully.

    Auth: Client must pass ?token=<firebase_id_token> query param.
    The token's UID must match the {user_id} path param.
    Bypassed when DEV_MODE=true.
    """
    await websocket.accept()

    # --- WebSocket auth: validate Firebase token from query param ---
    from app.middleware.auth import DEV_MODE, DEV_USER_ID, DEMO_MODE_ENABLED, DEMO_USER_ID, verify_firebase_token

    if DEV_MODE:
        # In dev mode, allow any connection; override user_id to dev user
        user_id = DEV_USER_ID
        logger.info("WebSocket connected (DEV_MODE): user=%s session=%s", user_id, session_id)
    elif DEMO_MODE_ENABLED and websocket.query_params.get("demo", "").lower() in ("true", "1"):
        user_id = DEMO_USER_ID
        logger.info("WebSocket connected (DEMO_MODE): user=%s session=%s", user_id, session_id)
    else:
        token = websocket.query_params.get("token")
        if not token:
            await websocket.send_json({"type": "error", "error": "Missing auth token"})
            await websocket.close(code=4401)
            return

        try:
            claims = verify_firebase_token(token)
        except Exception:
            await websocket.send_json({"type": "error", "error": "Invalid auth token"})
            await websocket.close(code=4401)
            return

        token_uid = claims.get("sub") or claims.get("user_id")
        if not token_uid or token_uid != user_id:
            await websocket.send_json({"type": "error", "error": "Token UID mismatch"})
            await websocket.close(code=4403)
            return

        logger.info("WebSocket connected: user=%s session=%s", user_id, session_id)

    agent_service = AgentService()

    # Determine agent from query params (default: noor)
    agent_name = websocket.query_params.get("agent", "noor")
    if agent_name not in VALID_AGENTS:
        agent_name = "noor"

    # Voice mode flag — enables Gemini Live audio response with per-agent voice
    voice_mode = websocket.query_params.get("voice", "false").lower() == "true"

    try:
        runner, live_request_queue, run_config, session = await agent_service.invoke_live(
            user_id=user_id,
            session_id=session_id,
            agent_name=agent_name,
            voice_mode=voice_mode,
        )
    except Exception as exc:
        logger.exception("Failed to set up bidi-streaming for user %s", user_id)
        await websocket.send_json({"type": "error", "error": str(exc)})
        await websocket.close()
        return

    # --- Upstream task: read from WebSocket, push to LiveRequestQueue ---
    async def upstream():
        """Read client messages and feed them into the LiveRequestQueue."""
        from google.genai import types

        try:
            while True:
                raw = await websocket.receive_text()
                msg = json.loads(raw)
                msg_type = msg.get("type", "text")

                if msg_type == "close":
                    live_request_queue.close()
                    break

                if msg_type == "text":
                    text = msg.get("text", "")
                    if text:
                        content = types.Content(
                            role="user",
                            parts=[types.Part(text=text)],
                        )
                        live_request_queue.send(content)

                elif msg_type == "audio":
                    import base64
                    audio_data = base64.b64decode(msg.get("data", ""))
                    mime_type = msg.get("mimeType", "audio/pcm")
                    blob = types.Blob(data=audio_data, mime_type=mime_type)
                    content = types.Content(
                        role="user",
                        parts=[types.Part(inline_data=blob)],
                    )
                    live_request_queue.send(content)

        except WebSocketDisconnect:
            logger.info("WebSocket disconnected (upstream): user=%s", user_id)
            live_request_queue.close()
        except Exception as exc:
            logger.exception("Upstream error for user %s", user_id)
            live_request_queue.close()

    # --- Downstream task: read from run_live(), send to WebSocket ---
    async def downstream():
        """Read events from the agent and send them to the client."""
        try:
            async for event_data in agent_service.stream_events(
                runner=runner,
                user_id=user_id,
                session_id=session.id,
                live_request_queue=live_request_queue,
                run_config=run_config,
            ):
                await websocket.send_json(event_data)
        except WebSocketDisconnect:
            logger.info("WebSocket disconnected (downstream): user=%s", user_id)
        except Exception as exc:
            logger.exception("Downstream error for user %s", user_id)
            try:
                await websocket.send_json({"type": "error", "error": str(exc)})
            except Exception:
                pass

    # Run upstream and downstream concurrently
    try:
        await asyncio.gather(upstream(), downstream())
    except Exception:
        logger.exception("WebSocket session error for user %s", user_id)
    finally:
        logger.info("WebSocket session ended: user=%s session=%s", user_id, session_id)
        try:
            await websocket.close()
        except Exception:
            pass


@router.websocket("/ws/chat/{user_id}")
async def websocket_chat_auto_session(
    websocket: WebSocket,
    user_id: str,
):
    """Convenience endpoint that auto-generates a session ID."""
    from app.db.base_repository import new_id
    session_id = new_id()
    await websocket_chat(websocket, user_id, session_id)
