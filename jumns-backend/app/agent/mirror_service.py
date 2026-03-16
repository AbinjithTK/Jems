"""Mirror Neuron Service — behavioral adaptation layer.

Agents gradually adapt their communication style to match the user's
patterns using exponential moving average (EMA) with alpha=0.05.
~20 interactions to shift a value by 50% — gradual, not jarring.

Profile is stored in Firestore (users/{userId}/mirror_profile doc)
and injected into agent instructions via before_agent_callback.
"""

from __future__ import annotations

import json
import logging
import re
from datetime import datetime, timezone
from typing import Any

from app.db.connection import get_firestore_client

logger = logging.getLogger(__name__)

EMA_ALPHA = 0.05  # ~20 interactions to shift 50%

DEFAULT_PROFILE: dict[str, Any] = {
    "formality": 0.5,
    "verbosity": 0.5,
    "emoji_affinity": 0.3,
    "humor_level": 0.5,
    "motivation_style": 0.5,  # 0=gentle, 1=tough love
    "active_hours": [7, 23],
    "top_topics": [],
    "interaction_count": 0,
    "last_updated": "",
}


class MirrorService:
    """Manages mirror neuron profiles in Firestore."""

    def __init__(self):
        self._db = get_firestore_client()

    def _doc_ref(self, user_id: str):
        """Mirror profile stored as users/{userId}/mirror_profile/current."""
        return (
            self._db.collection("users")
            .document(user_id)
            .collection("mirror_profile")
            .document("current")
        )

    def get_profile(self, user_id: str) -> dict[str, Any]:
        """Load mirror profile for a user, or return defaults."""
        try:
            doc = self._doc_ref(user_id).get()
            if doc.exists:
                return {**DEFAULT_PROFILE, **doc.to_dict()}
        except Exception:
            logger.debug("Mirror profile load failed for %s, using defaults", user_id)
        return {**DEFAULT_PROFILE}

    def save_profile(self, user_id: str, profile: dict[str, Any]) -> None:
        """Persist mirror profile to Firestore."""
        try:
            self._doc_ref(user_id).set(profile)
        except Exception:
            logger.warning("Mirror profile save failed for %s", user_id)

    def extract_signals(self, user_message: str) -> dict[str, float]:
        """Extract behavioral signals from a user message."""
        words = user_message.split()
        word_count = len(words)

        if word_count < 10:
            verbosity = 0.2
        elif word_count < 30:
            verbosity = 0.5
        else:
            verbosity = 0.9

        emoji_pattern = re.compile(
            r"[\U0001F600-\U0001F64F\U0001F300-\U0001F5FF"
            r"\U0001F680-\U0001F6FF\U0001F1E0-\U0001F1FF"
            r"\U00002702-\U000027B0\U0001F900-\U0001F9FF]"
        )
        emoji_count = len(emoji_pattern.findall(user_message))
        emoji_affinity = min(1.0, emoji_count * 0.3)

        casual_markers = ["lol", "haha", "omg", "bruh", "nah", "yep", "gonna",
                          "wanna", "gotta", "tbh", "imo", "idk", "rn", "ngl"]
        casual_count = sum(1 for w in words if w.lower().strip(".,!?") in casual_markers)
        formality = max(0.0, 0.7 - casual_count * 0.15)

        humor_markers = ["haha", "lol", "lmao", "😂", "🤣", "😄", "funny", "joke"]
        humor_count = sum(1 for w in words if w.lower().strip(".,!?") in humor_markers)
        humor_signal = min(1.0, humor_count * 0.3)

        return {
            "formality": formality,
            "verbosity": verbosity,
            "emoji_affinity": emoji_affinity,
            "humor_level": humor_signal,
        }

    def update_profile(
        self, user_id: str, profile: dict[str, Any], signals: dict[str, float],
    ) -> dict[str, Any]:
        """Apply EMA update to the profile with new signals."""
        updated = {**profile}
        for key, new_val in signals.items():
            if key in updated and isinstance(updated[key], (int, float)):
                old_val = float(updated[key])
                updated[key] = round(old_val * (1 - EMA_ALPHA) + new_val * EMA_ALPHA, 4)

        updated["interaction_count"] = profile.get("interaction_count", 0) + 1
        updated["last_updated"] = datetime.now(timezone.utc).isoformat()
        return updated

    def build_adaptation_prompt(self, profile: dict[str, Any]) -> str:
        """Generate the adaptation context string for agent instructions."""
        if profile.get("interaction_count", 0) < 3:
            return ""

        formality = profile.get("formality", 0.5)
        verbosity = profile.get("verbosity", 0.5)
        emoji = profile.get("emoji_affinity", 0.3)
        humor = profile.get("humor_level", 0.5)
        motivation = profile.get("motivation_style", 0.5)

        tone = "casual" if formality < 0.35 else "neutral" if formality < 0.65 else "formal"
        length = "concise" if verbosity < 0.35 else "moderate" if verbosity < 0.65 else "detailed"
        emoji_pref = "uses emojis frequently" if emoji > 0.5 else "rarely uses emojis"
        humor_pref = "responds well to humor" if humor > 0.5 else "prefers straightforward communication"
        motivation_pref = "gentle encouragement" if motivation < 0.4 else "balanced motivation" if motivation < 0.7 else "direct, tough-love style"

        return (
            f"\n\n## Adaptation Context\n"
            f"User prefers {tone} tone, {length} messages, {emoji_pref}, "
            f"{humor_pref}, and {motivation_pref}. "
            f"Adjust your personality accordingly while staying true to your core character."
        )
