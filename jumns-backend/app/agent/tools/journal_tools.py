"""Journal tools for Echo — CRUD + reflection prompts + mood tracking.

Echo owns the /journal screen. These tools let it create journal entries,
generate reflection prompts, track mood patterns, and manage the
infinite journaling board (polaroids, sticky notes, thought bubbles, audio).
"""

from __future__ import annotations

import random
from datetime import datetime, timezone

from app.db.repositories.journal import JournalRepository
from app.db.repositories.agent_context import AgentContextRepository
from app.memory.memory_service import MemoryService

_journal_repo = JournalRepository()
_context_repo = AgentContextRepository()
_memory_service = MemoryService()


def get_journal_entries(
    user_id: str, entry_type: str, limit: int,
) -> list[dict]:
    """Get journal entries, optionally filtered by type.

    Types: thought, reflection, polaroid, audio, sticky

    Args:
        user_id: The authenticated user's ID.
        entry_type: Filter by entry type. Use empty string for all types.
        limit: Max entries to return. Use 20 as a reasonable default.

    Returns:
        List of journal entry dicts.
    """
    actual_limit = limit if limit > 0 else 20
    entries = _journal_repo.list_all(user_id, entry_type=entry_type or None)
    return [
        {
            "id": e.get("id", ""),
            "type": e.get("type", "thought"),
            "title": e.get("title", ""),
            "content": e.get("content", "")[:300],
            "mood": e.get("mood"),
            "tags": e.get("tags", []),
            "shareable": e.get("shareable", False),
            "draft": e.get("draft", True),
            "createdAt": e.get("createdAt", ""),
        }
        for e in entries[:actual_limit]
    ]


def create_journal_entry(
    user_id: str,
    content: str,
    entry_type: str,
    title: str,
    mood: str,
    tags: str,
    shareable: str,
    linked_goal_id: str,
) -> dict:
    """Create a new journal entry on the infinite board.

    Entry types map to visual cards:
    - thought: Thought bubble card (rounded, subtle bg)
    - reflection: Full reflection card (prompted by you)
    - polaroid: Photo memory card (with image)
    - audio: Audio waveform card (voice note)
    - sticky: Sticky note (yellow tint, slight rotation)

    ALWAYS store the key insight as a memory after creating a reflection.

    Args:
        user_id: The authenticated user's ID.
        content: The journal text content.
        entry_type: One of: thought, reflection, polaroid, audio, sticky. Use "thought" if unsure.
        title: Title for the entry. Use empty string if none.
        mood: User's mood: happy, neutral, sad, anxious, energized, grateful. Use empty string if unknown.
        tags: Comma-separated tags (e.g. "work,stress,growth"). Use empty string if none.
        shareable: "true" if this entry can be shared with friends, "false" otherwise.
        linked_goal_id: Link to a goal if this reflection relates to one. Use empty string if none.

    Returns:
        The created journal entry dict.
    """
    tag_list = [t.strip() for t in tags.split(",") if t.strip()] if tags else []

    entry = _journal_repo.create(user_id, {
        "type": entry_type,
        "content": content,
        "title": title,
        "mood": mood or None,
        "tags": tag_list,
        "shareable": shareable.lower() == "true" if shareable else False,
        "draft": False,
        "agentPrompted": True,
        "linkedGoalId": linked_goal_id or None,
    })

    # Publish to context bus so other agents know
    _context_repo.publish(user_id, {
        "sourceAgent": "echo",
        "eventType": "journal_created",
        "summary": f"New {entry_type} journal entry: {title or content[:60]}",
        "details": {
            "entryId": entry.get("id", ""),
            "type": entry_type,
            "mood": mood or None,
            "tags": tag_list,
        },
        "targetAgents": ["all"],
    })

    # Auto-store as memory if it's a reflection
    if entry_type == "reflection" and content:
        _memory_service.store_structured(
            user_id, content[:500],
            category="reflection",
            importance="high",
            metadata={"journalEntryId": entry.get("id", ""), "mood": mood or None},
        )

    return {
        "id": entry.get("id", ""),
        "type": entry_type,
        "title": title,
        "mood": mood or None,
        "created": True,
    }


def generate_journal_prompt(user_id: str, prompt_type: str) -> dict:
    """Generate a thoughtful journal prompt based on the user's day and patterns.

    Prompt types:
    - evening: End-of-day reflection
    - morning: Intention setting
    - gratitude: What went well
    - growth: Learning and challenges
    - freeform: Open-ended creative prompt

    Args:
        user_id: The authenticated user's ID.
        prompt_type: Type of prompt to generate. Use "evening" as default.

    Returns:
        Dict with prompt question and context.
    """
    # Check recent context from other agents
    recent_context = _context_repo.get_recent(user_id, agent_name="echo", limit=10)
    context_hints = []
    for ctx in recent_context:
        if ctx.get("sourceAgent") != "echo":
            context_hints.append(ctx.get("summary", ""))

    # Check recent journal entries for patterns
    recent_entries = _journal_repo.list_all(user_id)[:5]
    recent_moods = [e.get("mood") for e in recent_entries if e.get("mood")]

    prompts = {
        "evening": [
            "What moment today made you feel most alive?",
            "If today had a title, what would it be?",
            "What's one thing you learned about yourself today?",
            "What would you tell your morning self about how today went?",
            "What's something small that happened today that you want to remember?",
        ],
        "morning": [
            "What's the one thing that would make today feel successful?",
            "How do you want to feel by the end of today?",
            "What's one intention you're setting for today?",
            "If today were a chapter in your story, what would happen?",
        ],
        "gratitude": [
            "Name three things you're grateful for right now.",
            "Who made your day better today, and how?",
            "What's a simple pleasure you enjoyed recently?",
        ],
        "growth": [
            "What challenged you recently, and what did it teach you?",
            "Where did you step outside your comfort zone?",
            "What skill or habit are you getting better at?",
        ],
        "freeform": [
            "Write about whatever's on your mind right now.",
            "Describe your current mood in three words, then explore why.",
            "What's been occupying your thoughts lately?",
        ],
    }

    actual_type = prompt_type if prompt_type else "evening"
    pool = prompts.get(actual_type, prompts["evening"])
    question = random.choice(pool)

    result: dict = {
        "prompt": question,
        "type": actual_type,
        "context": [],
    }

    if context_hints:
        result["context"] = context_hints[:3]
        result["contextNote"] = (
            "Consider weaving these recent events into your reflection."
        )

    if recent_moods:
        result["recentMoods"] = recent_moods[:5]

    return result


def get_mood_patterns(user_id: str, days: int) -> dict:
    """Analyze mood patterns from recent journal entries.

    Args:
        user_id: The authenticated user's ID.
        days: How many days back to analyze. Use 14 as a reasonable default.

    Returns:
        Mood pattern analysis with trends and insights.
    """
    entries = _journal_repo.list_all(user_id)

    moods: dict[str, int] = {}
    mood_timeline: list[dict] = []
    for e in entries[:50]:
        mood = e.get("mood")
        if mood:
            moods[mood] = moods.get(mood, 0) + 1
            mood_timeline.append({
                "mood": mood,
                "date": e.get("createdAt", "")[:10],
            })

    dominant = max(moods, key=moods.get) if moods else None
    total = sum(moods.values())

    return {
        "totalEntries": len(entries),
        "entriesWithMood": total,
        "moodDistribution": moods,
        "dominantMood": dominant,
        "timeline": mood_timeline[:14],
        "insight": _mood_insight(moods, dominant) if dominant else "Not enough data yet.",
    }


def _mood_insight(moods: dict, dominant: str = "") -> str:
    total = sum(moods.values())
    if not dominant or total < 3:
        return "Keep journaling — patterns emerge after a few entries."
    pct = round((moods[dominant] / total) * 100)
    if dominant in ("happy", "energized", "grateful"):
        return f"You've been feeling {dominant} {pct}% of the time. That's a great streak."
    if dominant in ("sad", "anxious"):
        return (
            f"You've been feeling {dominant} {pct}% of the time. "
            "Consider what's driving this — and whether a small change could help."
        )
    return f"Your dominant mood is {dominant} ({pct}%). Journaling helps you notice these patterns."
