"""Cloud Scheduler handlers for proactive agent behavior.

Each handler is an async function called by the scheduler route.
Cloud Scheduler POSTs to /api/scheduler/{job_name} which dispatches here.

Proactive invocations route through specific agents:
- morning_briefing → Kai (scheduler)
- evening_journal → Echo (memory/reflection)
- reminder_check → Kai
- plan_review → Sage (goals/growth)
- smart_suggestions → Sage
- memory_consolidation → Echo (consolidate patterns)
- goal_nudge → Sage (nudge stalled goals)
"""

from __future__ import annotations

import logging
from typing import Any

from app.agent.agent_service import AgentService
from app.db.repositories.users import UsersRepository

logger = logging.getLogger(__name__)

# Map job names to prompt types
VALID_JOBS = {
    "morning_briefing",
    "evening_journal",
    "reminder_check",
    "plan_review",
    "smart_suggestions",
    "memory_consolidation",
    "goal_nudge",
}


async def run_proactive(prompt_type: str) -> dict[str, Any]:
    """Run proactive agent invocation for all eligible users."""
    if prompt_type not in VALID_JOBS:
        return {"error": f"Unknown job: {prompt_type}", "processed": 0}

    agent = AgentService()
    try:
        repo = UsersRepository()
        user_ids = repo.list_all_users()
    except Exception:
        logger.exception("Failed to query eligible users")
        return {"processed": 0, "delivered": 0, "errors": 1}

    results: dict[str, Any] = {"processed": 0, "delivered": 0, "errors": 0}

    for user_id in user_ids:
        results["processed"] += 1
        try:
            result = await agent.invoke_proactive(user_id, prompt_type)
            if result is not None:
                results["delivered"] += 1
        except Exception:
            logger.exception(
                "Proactive %s failed for user %s", prompt_type, user_id,
            )
            results["errors"] += 1

    logger.info("Proactive %s: %s", prompt_type, results)
    return results
