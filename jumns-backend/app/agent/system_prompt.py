"""Legacy system prompt — DEPRECATED.

Agent personas are now defined in app/agent/personas/*.txt files.
Agent instructions are assembled in app/agent/agents.py.
This file is kept for backward compatibility with any imports.
"""

from __future__ import annotations


def build_system_prompt(settings: dict) -> str:
    """Legacy entry point — redirects to persona-based instructions."""
    from app.agent.agents import _build_instruction
    return _build_instruction("noor", settings, "", "")
