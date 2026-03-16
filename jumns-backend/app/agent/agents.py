"""Google ADK agent definitions — Noor, Kai, Sage, Echo.

Multi-agent hierarchy: Noor (root) with sub_agents [Kai, Sage, Echo].
Delegation via ADK's native transfer_to_agent.
Tools are plain functions wrapped by FunctionTool with user_id injection.

Differentiated models:
  - Noor: gemini-2.5-flash (Live-capable for voice streaming)
  - Kai/Sage/Echo: gemini-2.5-pro (richer tool calling + web search)

Dynamic integrations:
  - MCP toolsets loaded per-user from Firestore configs
  - Friend agents loaded as RemoteA2aAgent sub_agents via A2A
  - google_search built-in tool on Noor for web grounding
"""

from __future__ import annotations

import functools
import inspect
import logging
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from google.adk.agents import LlmAgent
from google.adk.agents.callback_context import CallbackContext
from google.adk.tools import FunctionTool
from google.genai import types

from app.agent.tools import KAI_TOOLS, SAGE_TOOLS, ECHO_TOOLS, NOOR_TOOLS
from app.db.repositories.agent_context import AgentContextRepository
from app.memory.memory_service import MemoryService

logger = logging.getLogger(__name__)

_context_repo = AgentContextRepository()
_memory_service = MemoryService()

PERSONAS_DIR = Path(__file__).parent / "personas"

# Differentiated models — Noor uses Live-capable flash, sub-agents use pro
MAIN_MODEL = os.getenv("JUMNS_MAIN_MODEL", "gemini-2.5-flash")
SUB_MODEL = os.getenv("JUMNS_SUB_MODEL", "gemini-2.5-pro")


def _load_persona(name: str) -> str:
    """Load persona instruction text from file."""
    path = PERSONAS_DIR / f"{name}.txt"
    if path.exists():
        return path.read_text(encoding="utf-8")
    return f"You are {name}, an AI assistant in the Jumns app."


def _bind_tools(tools: list, user_id: str) -> list[FunctionTool]:
    """Wrap plain functions as ADK FunctionTool with user_id pre-filled."""
    bound = []
    for fn in tools:
        sig = inspect.signature(fn)
        if "user_id" in sig.parameters:
            wrapper = functools.partial(fn, user_id=user_id)
            functools.update_wrapper(wrapper, fn)
            bound.append(FunctionTool(wrapper))
        else:
            bound.append(FunctionTool(fn))
    return bound


def _get_google_search_tool():
    """Load the ADK built-in GoogleSearchTool."""
    try:
        from google.adk.tools.google_search_tool import GoogleSearchTool
        return GoogleSearchTool()
    except (ImportError, Exception) as exc:
        logger.warning("GoogleSearchTool not available: %s", exc)
        return None


# ---------------------------------------------------------------------------
# before_agent_callback — injects session state before each agent turn
# ---------------------------------------------------------------------------

def _inject_state(callback_context: CallbackContext) -> types.Content | None:
    """Before-agent callback: inject memory bank + context bus into state."""
    state = callback_context.state
    user_id = state.get("user_id", "unknown")
    agent_name = callback_context.agent_name
    logger.debug("Injecting state for user %s into agent %s", user_id, agent_name)

    state["current_time"] = datetime.now(timezone.utc).isoformat()
    state["current_day"] = datetime.now(timezone.utc).strftime("%A")

    # Inject recent context bus events so agent knows what others did
    try:
        recent_ctx = _context_repo.get_recent(user_id, agent_name=agent_name, limit=10)
        other_agent_events = [
            f"[{e.get('sourceAgent', '?')}] {e.get('eventType', '')}: {e.get('summary', '')}"
            for e in recent_ctx if e.get("sourceAgent") != agent_name
        ]
        if other_agent_events:
            state["recent_agent_activity"] = other_agent_events[:8]
    except Exception:
        pass

    return None


# ---------------------------------------------------------------------------
# Instruction builder
# ---------------------------------------------------------------------------

def _build_instruction(
    persona_name: str,
    settings: dict[str, Any],
    mirror_prompt: str,
    context_block: str = "",
    user_id: str = "",
) -> str:
    """Assemble full instruction from persona file + dynamic context."""
    now = datetime.now(timezone.utc)
    base = _load_persona(persona_name)

    time_context = (
        f"\n\n## Current Context\n"
        f"- Date/Time: {now.strftime('%A, %B %d, %Y at %I:%M %p UTC')}\n"
        f"- User Timezone: {settings.get('timezone', 'UTC')}\n"
        f"- Day of Week: {now.strftime('%A')}"
    )

    instruction = base + time_context

    # Inject per-agent memory summary
    if user_id:
        try:
            agent_categories = {
                "noor": None,  # Noor sees all categories
                "kai": "habit",
                "sage": "goal_context",
                "echo": "reflection",
            }
            cat = agent_categories.get(persona_name)
            bank = _memory_service.get_memory_bank_summary(user_id)
            if bank.get("total_memories", 0) > 0:
                instruction += (
                    f"\n\n## Memory Bank\n"
                    f"- Total memories: {bank['total_memories']}\n"
                    f"- Categories: {', '.join(f'{k}({v})' for k, v in bank.get('by_category', {}).items())}"
                )
                critical = bank.get("critical_memories", [])
                if critical:
                    instruction += "\n- Critical facts:"
                    for cm in critical[:3]:
                        instruction += f"\n  - {cm.get('content', '')}"
        except Exception:
            pass

        # Inject recent context bus activity
        try:
            recent_ctx = _context_repo.get_recent(user_id, agent_name=persona_name, limit=8)
            other_events = [
                e for e in recent_ctx if e.get("sourceAgent") != persona_name
            ]
            if other_events:
                instruction += "\n\n## Recent Agent Activity"
                for e in other_events[:5]:
                    instruction += (
                        f"\n- [{e.get('sourceAgent', '?')}] "
                        f"{e.get('eventType', '')}: {e.get('summary', '')}"
                    )
        except Exception:
            pass

    if mirror_prompt:
        instruction += mirror_prompt
    if context_block:
        instruction += context_block
    return instruction


# ---------------------------------------------------------------------------
# Agent builders
# ---------------------------------------------------------------------------

def build_agent_hierarchy(
    user_id: str,
    settings: dict[str, Any],
    mirror_prompt: str = "",
    memory_context: str = "",
    mcp_toolsets: list | None = None,
    friend_agents: list | None = None,
) -> LlmAgent:
    """Build the full Noor → [Kai, Sage, Echo] agent hierarchy.

    Returns the root Noor agent with sub_agents configured.
    Sub-agents use SUB_MODEL (gemini-2.5-pro) for richer tool calling.
    Noor uses MAIN_MODEL (gemini-2.5-flash) for Live voice capability.

    Optional:
      mcp_toolsets: list of MCPToolset instances loaded from user's MCP configs
      friend_agents: list of RemoteA2aAgent instances for accepted A2A friends
    """
    kai = LlmAgent(
        name="kai",
        model=SUB_MODEL,
        instruction=_build_instruction("kai", settings, mirror_prompt, user_id=user_id),
        tools=_bind_tools(KAI_TOOLS, user_id),
        description="Kai — the Scheduler agent. Handles tasks, reminders, calendar, and planning.",
        before_agent_callback=_inject_state,
    )

    sage = LlmAgent(
        name="sage",
        model=SUB_MODEL,
        instruction=_build_instruction("sage", settings, mirror_prompt, user_id=user_id),
        tools=_bind_tools(SAGE_TOOLS, user_id),
        description="Sage — the Goals & Growth agent. Handles goals, progress analysis, social briefings, and insights.",
        before_agent_callback=_inject_state,
    )

    echo = LlmAgent(
        name="echo",
        model=SUB_MODEL,
        instruction=_build_instruction("echo", settings, mirror_prompt, user_id=user_id),
        tools=_bind_tools(ECHO_TOOLS, user_id),
        description="Echo — the Memory & Reflection agent. Handles memories, journaling, mood tracking, and recall.",
        before_agent_callback=_inject_state,
    )

    # Noor tools: base tools + MCP toolsets
    # NOTE: GoogleSearchTool cannot be combined with FunctionTool in the same
    # request (Gemini API limitation). Omit it when function tools are present.
    noor_tools: list = _bind_tools(NOOR_TOOLS, user_id)

    if mcp_toolsets:
        noor_tools.extend(mcp_toolsets)

    # Sub-agents: core team + friend agents via A2A
    sub_agents: list = [kai, sage, echo]
    if friend_agents:
        sub_agents.extend(friend_agents)

    noor = LlmAgent(
        name="noor",
        model=MAIN_MODEL,
        instruction=_build_instruction("noor", settings, mirror_prompt, memory_context, user_id=user_id),
        tools=noor_tools,
        sub_agents=sub_agents,
        description="Noor — the main conversational agent. Orchestrates and delegates to Kai, Sage, Echo, and friend agents.",
        before_agent_callback=_inject_state,
    )

    return noor


def build_single_agent(
    agent_name: str,
    user_id: str,
    settings: dict[str, Any],
    mirror_prompt: str = "",
    mcp_toolsets: list | None = None,
) -> LlmAgent:
    """Build a single named agent for direct tab communication."""
    tool_map = {
        "kai": KAI_TOOLS,
        "sage": SAGE_TOOLS,
        "echo": ECHO_TOOLS,
        "noor": NOOR_TOOLS,
    }
    # Noor uses flash for Live, sub-agents use pro
    model = MAIN_MODEL if agent_name == "noor" else SUB_MODEL
    tools_list = _bind_tools(tool_map.get(agent_name, NOOR_TOOLS), user_id)

    # Add MCP toolsets to Noor even in single-agent mode
    # NOTE: GoogleSearchTool omitted — cannot combine with FunctionTool
    if agent_name == "noor":
        if mcp_toolsets:
            tools_list.extend(mcp_toolsets)

    return LlmAgent(
        name=agent_name,
        model=model,
        instruction=_build_instruction(agent_name, settings, mirror_prompt, user_id=user_id),
        tools=tools_list,
        description=f"{agent_name.capitalize()} agent for direct communication.",
        before_agent_callback=_inject_state,
    )
