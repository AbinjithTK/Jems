"""Google ADK Agent Service — multi-agent orchestration with bidi-streaming.

Supports two modes:
1. REST invoke() — standard request/response via Runner.run_async()
2. Bidi-streaming invoke_live() — real-time WebSocket via Runner.run_live()
   with LiveRequestQueue for upstream and async generator for downstream.

Mirror neuron system adapts agent tone via before/after callbacks.
Memory bank integration via session state injection.
"""

from __future__ import annotations

import json
import logging
import os
import os
import re
from typing import Any, AsyncGenerator

from app.agent.mirror_service import MirrorService
from app.db.repositories.messages import MessagesRepository
from app.db.repositories.users import UsersRepository
from app.exceptions import AgentUnavailableError
from app.memory.memory_service import MemoryService

logger = logging.getLogger(__name__)

# Card block parser — extracts :::card{type="X"} ... ::: from agent output
_CARD_PATTERN = re.compile(
    r':::card\{type="([^"]+)"\}\s*(.*?)\s*:::', re.DOTALL
)


def parse_card_blocks(text: str) -> tuple[str, str | None, dict | None]:
    """Parse card blocks from agent response text."""
    match = _CARD_PATTERN.search(text)
    if not match:
        return text, None, None

    card_type = match.group(1)
    card_body = match.group(2).strip()

    card_data: dict | None = None
    try:
        card_data = json.loads(card_body)
    except (json.JSONDecodeError, ValueError):
        card_data = {"content": card_body}

    clean_text = text[: match.start()].strip()
    trailing = text[match.end() :].strip()
    if trailing:
        clean_text = f"{clean_text}\n{trailing}" if clean_text else trailing

    return clean_text, card_type, card_data


# Navigation event pattern
_NAV_PATTERN = re.compile(
    r'"action"\s*:\s*"navigate".*?"route"\s*:\s*"([^"]+)"', re.DOTALL
)


def _extract_navigation(text: str) -> dict | None:
    """Extract navigation event from agent response if present."""
    match = _NAV_PATTERN.search(text)
    if match:
        try:
            nav_start = text.rfind("{", 0, match.start())
            nav_end = text.find("}", match.end()) + 1
            if nav_start >= 0 and nav_end > 0:
                return json.loads(text[nav_start:nav_end])
        except (json.JSONDecodeError, ValueError):
            return {"action": "navigate", "route": match.group(1)}
    return None


def _extract_agent_name(events: list) -> str:
    """Determine which agent produced the final response from ADK events."""
    for event in reversed(events):
        author = getattr(event, "author", None)
        if author and author in ("noor", "kai", "sage", "echo"):
            return author
    return "noor"


def _collect_response_text(events: list) -> str:
    """Collect the final text response from ADK runner events."""
    texts = []
    for event in events:
        if not hasattr(event, "content"):
            continue
        content = event.content
        if content and hasattr(content, "parts"):
            for part in content.parts:
                if hasattr(part, "text") and part.text:
                    texts.append(part.text)
    return "\n".join(texts) if texts else ""


class AgentService:
    """Google ADK multi-agent service with bidi-streaming and mirror neurons.

    Modes:
    - invoke(): REST request/response via Runner.run_async()
    - invoke_live(): Bidi-streaming via Runner.run_live() + LiveRequestQueue
    - invoke_proactive(): Scheduled autonomous agent actions
    """

    def __init__(self):
        self._users_repo = UsersRepository()
        self._messages_repo = MessagesRepository()
        self._memory_service = MemoryService()
        self._mirror_service = MirrorService()
        self._mcp_service: Any = None
        self._a2a_service: Any = None

    def _get_mcp_service(self):
        if self._mcp_service is None:
            from app.connections.mcp_service import McpService
            self._mcp_service = McpService()
        return self._mcp_service

    def _get_a2a_service(self):
        if self._a2a_service is None:
            from app.connections.a2a_service import A2aService
            self._a2a_service = A2aService()
        return self._a2a_service

    async def _load_dynamic_integrations(self, user_id: str) -> tuple[list, list]:
        """Load MCP toolsets and friend agents for a user. Non-fatal."""
        mcp_toolsets: list = []
        friend_agents: list = []

        # Skip MCP/A2A in dev mode — no external servers available
        if os.getenv("DEV_MODE", "").lower() == "true":
            return mcp_toolsets, friend_agents

        try:
            mcp_toolsets = await self._get_mcp_service().load_toolsets(user_id)
        except Exception:
            logger.debug("MCP toolset loading failed for user %s", user_id, exc_info=True)
        try:
            friend_agents = self._get_a2a_service().load_friend_agents(user_id)
        except Exception:
            logger.debug("A2A friend loading failed for user %s", user_id, exc_info=True)
        return mcp_toolsets, friend_agents

    # ------------------------------------------------------------------
    # REST mode — standard request/response
    # ------------------------------------------------------------------

    async def invoke(
        self,
        user_id: str,
        message: str,
        agent_name: str = "noor",
    ) -> dict[str, Any]:
        """Run a chat turn through the ADK agent hierarchy (REST mode)."""
        settings = self._users_repo.get_settings(user_id)

        mirror_profile = self._mirror_service.get_profile(user_id)
        mirror_prompt = self._mirror_service.build_adaptation_prompt(mirror_profile)
        memory_context = self._build_memory_context(user_id, message)

        # Load dynamic integrations (MCP toolsets + A2A friend agents)
        mcp_toolsets, friend_agents = await self._load_dynamic_integrations(user_id)

        try:
            if agent_name == "noor":
                from app.agent.agents import build_agent_hierarchy
                root_agent = build_agent_hierarchy(
                    user_id, settings, mirror_prompt, memory_context,
                    mcp_toolsets=mcp_toolsets,
                    friend_agents=friend_agents,
                )
            else:
                from app.agent.agents import build_single_agent
                root_agent = build_single_agent(
                    agent_name, user_id, settings, mirror_prompt,
                    mcp_toolsets=mcp_toolsets,
                )
        except ImportError:
            logger.warning("Google ADK not installed, using dev fallback")
            return self._dev_fallback(message, agent_name)

        try:
            response_text, responding_agent, delegated_to = await self._run_agent(
                root_agent, user_id, message,
            )
        except Exception as exc:
            logger.exception("ADK agent invocation failed for user %s", user_id)
            raise AgentUnavailableError() from exc

        clean_text, card_type, card_data = parse_card_blocks(response_text)
        navigation = _extract_navigation(response_text)

        # Mirror neuron update (non-fatal)
        try:
            signals = self._mirror_service.extract_signals(message)
            updated_profile = self._mirror_service.update_profile(
                user_id, mirror_profile, signals,
            )
            self._mirror_service.save_profile(user_id, updated_profile)
        except Exception:
            pass

        # Persist messages
        self._messages_repo.create_message(user_id, {
            "role": "user", "type": "text", "content": message,
        })
        assistant_msg: dict[str, Any] = {
            "role": "assistant",
            "type": "card" if card_type else "text",
            "content": clean_text or response_text,
            "agent": responding_agent,
        }
        if card_type:
            assistant_msg["cardType"] = card_type
            assistant_msg["cardData"] = card_data
        self._messages_repo.create_message(user_id, assistant_msg)

        # Store memory (best-effort)
        try:
            self._memory_service.extract_and_store(
                user_id,
                f"User: {message}\n{responding_agent.capitalize()}: {clean_text or response_text}",
            )
        except Exception:
            pass

        result: dict[str, Any] = {
            "content": clean_text or response_text,
            "cardType": card_type,
            "cardData": card_data,
            "agent": responding_agent,
        }
        if delegated_to and delegated_to != responding_agent:
            result["delegatedTo"] = delegated_to
        if navigation:
            result["navigation"] = navigation
        return result

    # ------------------------------------------------------------------
    # Bidi-streaming mode — real-time WebSocket via run_live()
    # ------------------------------------------------------------------

    # Per-agent Gemini Live voice profiles
    AGENT_VOICE_PROFILES: dict[str, str] = {
        "noor": "Aoede",    # Warm, friendly — matches green main agent
        "kai": "Kore",      # Clear, structured — matches yellow planner
        "sage": "Charon",   # Thoughtful, authoritative — matches pink advisor
        "echo": "Fenrir",   # Quiet, gentle — matches violet archivist
    }

    async def invoke_live(
        self,
        user_id: str,
        session_id: str,
        agent_name: str = "noor",
        voice_mode: bool = False,
    ) -> tuple[Any, Any, Any, Any]:
        """Set up bidi-streaming agent session.

        Returns (runner, live_request_queue, run_config, adk_session)
        for the WebSocket handler to manage upstream/downstream.

        When voice_mode=True, configures SpeechConfig with per-agent
        voice profiles and response_modalities=["AUDIO"].
        """
        try:
            from google.adk.agents.live_request_queue import LiveRequestQueue
            from google.adk.agents.run_config import RunConfig, StreamingMode
            from google.adk.runners import Runner
            from google.adk.sessions import InMemorySessionService
            from google.genai import types
        except ImportError:
            logger.warning("Google ADK not installed — live streaming unavailable")
            raise AgentUnavailableError()

        settings = self._users_repo.get_settings(user_id)
        mirror_profile = self._mirror_service.get_profile(user_id)
        mirror_prompt = self._mirror_service.build_adaptation_prompt(mirror_profile)

        # Load dynamic integrations (MCP toolsets + A2A friend agents)
        mcp_toolsets, friend_agents = await self._load_dynamic_integrations(user_id)

        if agent_name == "noor":
            from app.agent.agents import build_agent_hierarchy
            memory_context = self._build_memory_context(user_id, "")
            agent = build_agent_hierarchy(
                user_id, settings, mirror_prompt, memory_context,
                mcp_toolsets=mcp_toolsets,
                friend_agents=friend_agents,
            )
        else:
            from app.agent.agents import build_single_agent
            agent = build_single_agent(
                agent_name, user_id, settings, mirror_prompt,
                mcp_toolsets=mcp_toolsets,
            )

        session_service = InMemorySessionService()
        runner = Runner(
            agent=agent,
            app_name="jumns",
            session_service=session_service,
        )

        # Create session with user context in state
        session = await session_service.create_session(
            app_name="jumns",
            user_id=user_id,
            session_id=session_id,
            state={
                "user_id": user_id,
                "agent_name": agent_name,
                "settings": settings,
                "voice_mode": voice_mode,
                "mirror_profile": {
                    k: v for k, v in mirror_profile.items()
                    if k != "embedding"
                },
            },
        )

        # Load conversation history into state
        history = self._load_history(user_id)
        if history:
            session.state["conversation_history"] = history

        # Load memory bank into state
        memory_bank = self._memory_service.list_memories(user_id)
        if memory_bank:
            session.state["memory_bank_size"] = len(memory_bank)
            recent = memory_bank[-10:] if len(memory_bank) > 10 else memory_bank
            session.state["recent_memories"] = [
                m.get("content", "")[:200] for m in recent
            ]

        live_request_queue = LiveRequestQueue()

        # Build RunConfig — with voice profile when in voice mode
        if voice_mode:
            voice_name = self.AGENT_VOICE_PROFILES.get(agent_name, "Aoede")
            run_config = RunConfig(
                streaming_mode=StreamingMode.BIDI,
                response_modalities=["AUDIO"],
                speech_config=types.SpeechConfig(
                    voice_config=types.VoiceConfig(
                        prebuilt_voice_config=types.PrebuiltVoiceConfig(
                            voice_name=voice_name,
                        ),
                    ),
                    language_code="en-US",
                ),
            )
            logger.info(
                "Voice mode: user=%s agent=%s voice=%s",
                user_id, agent_name, voice_name,
            )
        else:
            run_config = RunConfig(streaming_mode=StreamingMode.BIDI)

        return runner, live_request_queue, run_config, session

    async def stream_events(
        self,
        runner: Any,
        user_id: str,
        session_id: str,
        live_request_queue: Any,
        run_config: Any,
    ) -> AsyncGenerator[dict[str, Any], None]:
        """Async generator that yields processed events from run_live().

        The WebSocket handler iterates this to send events downstream.
        """
        try:
            async for event in runner.run_live(
                user_id=user_id,
                session_id=session_id,
                live_request_queue=live_request_queue,
                run_config=run_config,
            ):
                event_data = self._process_live_event(event)
                if event_data:
                    yield event_data
        except Exception as exc:
            logger.exception("Bidi-streaming error for user %s", user_id)
            yield {
                "type": "error",
                "error": str(exc),
            }

    def _process_live_event(self, event: Any) -> dict[str, Any] | None:
        """Convert an ADK Event into a JSON-serializable dict for the client."""
        result: dict[str, Any] = {
            "type": "event",
            "author": getattr(event, "author", None),
        }

        # Check for text content
        content = getattr(event, "content", None)
        if content and hasattr(content, "parts"):
            for part in content.parts:
                if hasattr(part, "text") and part.text:
                    text = part.text
                    clean_text, card_type, card_data = parse_card_blocks(text)
                    result["text"] = clean_text or text
                    if card_type:
                        result["cardType"] = card_type
                        result["cardData"] = card_data
                    navigation = _extract_navigation(text)
                    if navigation:
                        result["navigation"] = navigation
                    return result

                # Audio data (inline)
                if hasattr(part, "inline_data") and part.inline_data:
                    import base64
                    result["type"] = "audio"
                    result["mimeType"] = getattr(
                        part.inline_data, "mime_type", "audio/pcm"
                    )
                    raw_data = getattr(part.inline_data, "data", b"")
                    if raw_data:
                        result["data"] = base64.b64encode(raw_data).decode("ascii")
                    return result

        # Check for turn_complete / interrupted flags
        if getattr(event, "turn_complete", False):
            return {"type": "turn_complete", "author": result.get("author")}
        if getattr(event, "interrupted", False):
            return {"type": "interrupted", "author": result.get("author")}

        # Tool call events
        if getattr(event, "function_calls", None):
            calls = []
            for fc in event.function_calls:
                calls.append({
                    "name": getattr(fc, "name", ""),
                    "args": getattr(fc, "args", {}),
                })
            return {
                "type": "tool_call",
                "author": result.get("author"),
                "calls": calls,
            }

        # Error events
        if getattr(event, "error_code", None) or getattr(event, "error_message", None):
            return {
                "type": "error",
                "errorCode": getattr(event, "error_code", None),
                "errorMessage": getattr(event, "error_message", None),
            }

        return None


    # ------------------------------------------------------------------
    # Proactive invocations (scheduled / autonomous)
    # ------------------------------------------------------------------

    async def invoke_proactive(
        self, user_id: str, prompt_type: str,
    ) -> dict[str, Any] | None:
        """Proactive invocation for scheduled briefings, reviews, etc."""
        agent_routing = {
            "morning_briefing": "kai",
            "evening_journal": "echo",
            "reminder_check": "kai",
            "plan_review": "sage",
            "smart_suggestions": "sage",
            "memory_consolidation": "echo",
            "goal_nudge": "sage",
        }

        prompts = {
            "morning_briefing": (
                "Generate a morning briefing. Use get_daily_summary to check "
                "the user's goals, tasks, and reminders. Create a briefing card "
                'using :::card{type="daily_briefing"} format with JSON payload: '
                "title, greeting, tasks (array), goals (array), reminders (array). "
                "If nothing meaningful, respond with __SILENT__."
            ),
            "evening_journal": (
                "Generate an evening journal prompt. Use recall_memories to "
                "review recent conversations. Create a journal card using "
                ':::card{type="journal_prompt"} format with JSON payload: '
                "title, reflection_questions (array), accomplishments (array). "
                "If nothing meaningful, respond with __SILENT__."
            ),
            "reminder_check": (
                "Check for active reminders due now. Use get_reminders. "
                'For each due reminder, create a :::card{type="reminder"} block. '
                "If none due, respond with __SILENT__."
            ),
            "plan_review": (
                "Review all active goals. Use get_goals to find active goals, "
                "then call adapt_plan for each. If any have overdue tasks, call "
                "reschedule_failed_tasks. Summarize findings using "
                ':::card{type="progress_report"} format. '
                "If nothing to report, respond with __SILENT__."
            ),
            "smart_suggestions": (
                "Generate proactive suggestions. Call smart_suggest with "
                "focus='all'. Present the top suggestions using "
                ':::card{type="suggestion"} format. '
                "If no suggestions, respond with __SILENT__."
            ),
            "memory_consolidation": (
                "Review recent memories using recall_memories with topic='recent'. "
                "Identify patterns, recurring themes, or important facts that "
                "should be highlighted. Store any consolidated insights using "
                "remember_fact. If nothing notable, respond with __SILENT__."
            ),
            "goal_nudge": (
                "Check goals that haven't had progress in 3+ days using "
                "analyze_progress. For stalled goals, generate a gentle nudge "
                ':::card{type="goal_check_in"} with encouragement and a '
                "concrete next step. If all goals are on track, respond with __SILENT__."
            ),
        }

        prompt = prompts.get(prompt_type)
        if not prompt:
            return None

        target_agent = agent_routing.get(prompt_type, "noor")

        try:
            result = await self.invoke(user_id, prompt, agent_name=target_agent)
            if "__SILENT__" in result.get("content", ""):
                return None
            return result
        except AgentUnavailableError:
            return None

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    async def _run_agent(
        self,
        agent: Any,
        user_id: str,
        message: str,
    ) -> tuple[str, str, str | None]:
        """Execute the ADK Runner and collect results."""
        from google.adk.runners import Runner
        from google.adk.sessions import InMemorySessionService
        from google.genai import types

        session_service = InMemorySessionService()
        runner = Runner(
            agent=agent,
            app_name="jumns",
            session_service=session_service,
        )

        session = await session_service.create_session(
            app_name="jumns",
            user_id=user_id,
            state={
                "user_id": user_id,
            },
        )

        # Load conversation history into session state
        history = self._load_history(user_id)
        if history:
            session.state["conversation_history"] = history

        # Load memory bank summary into state
        try:
            memories = self._memory_service.search(user_id, message, top_k=5)
            if memories:
                session.state["relevant_memories"] = [
                    m.get("content", "")[:200] for m in memories
                ]
        except Exception:
            pass

        events = []
        new_message = types.Content(
            role="user",
            parts=[types.Part(text=message)],
        )

        async for event in runner.run_async(
            user_id=user_id,
            session_id=session.id,
            new_message=new_message,
        ):
            events.append(event)

        response_text = _collect_response_text(events)
        responding_agent = _extract_agent_name(events)

        delegated_to = None
        for event in events:
            author = getattr(event, "author", None)
            if author and author != agent.name and author in ("kai", "sage", "echo"):
                delegated_to = author
                break

        if not response_text:
            response_text = "I'm here! Could you say that again?"

        return response_text, responding_agent, delegated_to

    def _build_memory_context(self, user_id: str, message: str) -> str:
        """Search vector memory and return a context block."""
        try:
            memories = self._memory_service.search(user_id, message, top_k=5)
            if memories:
                snippets = [m.get("content", "") for m in memories if m.get("content")]
                if snippets:
                    return (
                        "\n\n## Relevant Memories\n"
                        + "\n".join(f"- {s}" for s in snippets[:5])
                    )
        except Exception:
            pass
        return ""

    def _load_history(self, user_id: str) -> list[dict]:
        """Load recent conversation history from Firestore."""
        history = self._messages_repo.list_messages(user_id)
        recent = history[-20:] if len(history) > 20 else history
        messages = []
        for msg in recent:
            role = msg.get("role", "user")
            content = msg.get("content", "")
            if role in ("user", "assistant") and content:
                messages.append({"role": role, "content": content})
        return messages

    def _dev_fallback(self, message: str, agent_name: str) -> dict[str, Any]:
        """Dev mode fallback when ADK is not installed."""
        return {
            "content": (
                f"[{agent_name.capitalize()} — dev mode] I received: '{message}'. "
                "The Google ADK is not installed. Deploy with google-adk for full agent capabilities."
            ),
            "cardType": None,
            "cardData": None,
            "agent": agent_name,
        }
