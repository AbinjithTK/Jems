"""Routes for /api/scheduler — Cloud Scheduler HTTP targets.

Cloud Scheduler sends POST requests to trigger proactive agent behavior.
These endpoints are authenticated via a shared secret header (not Firebase Auth)
since Cloud Scheduler uses OIDC or a static token.

Schedule recommendations:
- morning_briefing: 0 7 * * * (daily 7 AM user timezone)
- evening_journal: 0 21 * * * (daily 9 PM user timezone)
- reminder_check: */5 * * * * (every 5 minutes)
- plan_review: 0 18 * * * (daily 6 PM)
- smart_suggestions: 0 10,15 * * * (twice daily)
- memory_consolidation: 0 3 * * * (daily 3 AM — off-peak)
- goal_nudge: 0 12 * * * (daily noon)
"""

from __future__ import annotations

import os

from fastapi import APIRouter, Header, HTTPException

from app.scheduler.handler import VALID_JOBS, run_proactive

router = APIRouter(prefix="/scheduler", tags=["scheduler"])

SCHEDULER_SECRET = os.getenv("SCHEDULER_SECRET", "")


def _verify_scheduler_auth(authorization: str | None) -> None:
    """Verify the request comes from Cloud Scheduler.

    In production, use OIDC token validation or a shared secret.
    In dev mode (no SCHEDULER_SECRET set), all requests are allowed.
    """
    if not SCHEDULER_SECRET:
        return  # Dev mode — no auth required
    if not authorization or authorization != f"Bearer {SCHEDULER_SECRET}":
        raise HTTPException(status_code=403, detail="Invalid scheduler token")


@router.post("/{job_name}")
async def trigger_job(
    job_name: str,
    authorization: str | None = Header(None),
) -> dict:
    """Cloud Scheduler target — triggers a proactive agent job.

    POST /api/scheduler/morning_briefing
    POST /api/scheduler/reminder_check
    etc.
    """
    _verify_scheduler_auth(authorization)

    if job_name not in VALID_JOBS:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown job: {job_name}. Valid: {', '.join(sorted(VALID_JOBS))}",
        )

    result = await run_proactive(job_name)
    return {"job": job_name, **result}


@router.get("/jobs")
async def list_jobs(
    authorization: str | None = Header(None),
) -> dict:
    """List all available scheduler jobs and their descriptions."""
    _verify_scheduler_auth(authorization)
    return {
        "jobs": [
            {"name": "morning_briefing", "agent": "kai", "schedule": "0 7 * * *", "description": "Daily morning briefing with schedule overview"},
            {"name": "evening_journal", "agent": "echo", "schedule": "0 21 * * *", "description": "Evening journal prompt based on the day's activity"},
            {"name": "reminder_check", "agent": "kai", "schedule": "*/5 * * * *", "description": "Check for due reminders"},
            {"name": "plan_review", "agent": "sage", "schedule": "0 18 * * *", "description": "Review goal progress and adapt plans"},
            {"name": "smart_suggestions", "agent": "sage", "schedule": "0 10,15 * * *", "description": "Generate proactive suggestions"},
            {"name": "memory_consolidation", "agent": "echo", "schedule": "0 3 * * *", "description": "Consolidate memory patterns"},
            {"name": "goal_nudge", "agent": "sage", "schedule": "0 12 * * *", "description": "Nudge stalled goals"},
        ]
    }
