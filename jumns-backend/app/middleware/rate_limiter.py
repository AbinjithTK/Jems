"""Free-tier rate limiting — 10 chat messages per calendar day.

Disabled in DEV_MODE for local development.
"""

from __future__ import annotations

import logging
import os
from datetime import datetime, timezone

from app.db.repositories.messages import MessagesRepository
from app.exceptions import RateLimitExceededError

logger = logging.getLogger(__name__)

FREE_TIER_LIMIT = 10
DEV_MODE = os.getenv("DEV_MODE", "").lower() in ("true", "1", "yes")


async def check_rate_limit(user_id: str) -> None:
    """Raise RateLimitExceededError if free-tier daily limit is reached.

    Skipped in DEV_MODE.
    """
    if DEV_MODE:
        return

    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    repo = MessagesRepository()
    count = repo.count_user_messages_today(user_id, today)
    if count >= FREE_TIER_LIMIT:
        raise RateLimitExceededError(FREE_TIER_LIMIT)
