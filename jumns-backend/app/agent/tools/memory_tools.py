"""Vector memory tools — search, store, recall with proper category/importance.

Fixed: remember_fact now passes category/importance to store_structured()
instead of hardcoding. recall_memories supports agent-scoped filtering.
"""

from __future__ import annotations

from app.memory.memory_service import MemoryService


_memory_service = MemoryService()


def search_memory(
    user_id: str,
    query: str,
    top_k: int,
    category: str,
    min_importance: str,
) -> list[dict]:
    """Search the user's long-term memory for relevant context.

    Uses cosine similarity over embeddings. The search is semantic.
    Optionally filter by category and minimum importance level.

    Args:
        user_id: The authenticated user's ID.
        query: Natural language search query.
        top_k: Maximum number of results to return. Use 5 as a reasonable default.
        category: Filter by category (preference, personal_info, goal_context,
                  habit, important_date, relationship, health, work, skill,
                  emotional, pattern, reflection, fact). Use empty string for all.
        min_importance: Minimum importance level (critical, high, medium, low). Use "low" to include all.

    Returns:
        List of memory dicts with content, category, importance, score, createdAt.
    """
    results = _memory_service.search(
        user_id, query, top_k=top_k,
        category=category or None, min_importance=min_importance,
    )
    return [
        {
            "content": m.get("content", ""),
            "category": m.get("category", "fact"),
            "importance": m.get("importance", "medium"),
            "score": round(m.get("score", 0), 2),
            "createdAt": m.get("createdAt", ""),
        }
        for m in results
    ]


def remember_fact(
    user_id: str,
    content: str,
    category: str,
    importance: str,
) -> dict:
    """Store an important fact about the user in long-term memory.

    Use when the user shares personal information, preferences, habits,
    important dates, or anything worth remembering for future conversations.

    Categories and when to use them:
    - preference: likes/dislikes, favorite things, style choices
    - personal_info: name, age, job, location, family
    - goal_context: context about why a goal matters, motivation
    - habit: routines, patterns, regular activities
    - important_date: birthdays, anniversaries, deadlines
    - relationship: people in their life, connections
    - health: medical info, fitness data, diet, sleep
    - work: job details, projects, colleagues
    - skill: things they're learning or good at
    - emotional: emotional states, triggers, coping strategies
    - pattern: recurring behavioral patterns you've noticed
    - reflection: insights from journaling or self-reflection

    Importance levels:
    - critical: names, health conditions, allergies — never forget
    - high: preferences, relationships, active goals
    - medium: habits, interests, casual context
    - low: one-off mentions, minor details

    Args:
        user_id: The authenticated user's ID.
        content: The fact to remember (e.g. "User prefers morning workouts").
        category: Memory category (see above).
        importance: One of: critical, high, medium, low.

    Returns:
        Confirmation dict with stored memory ID.
    """
    memory_id = _memory_service.store_structured(
        user_id,
        content,
        category=category,
        importance=importance,
    )
    if memory_id:
        return {
            "stored": True,
            "memoryId": memory_id,
            "content": content,
            "category": category,
            "importance": importance,
        }
    return {"stored": False, "reason": "Memory storage failed"}


def recall_memories(
    user_id: str,
    query: str,
    category: str,
    limit: int,
) -> dict:
    """Recall facts about the user from long-term memory.

    Use when you need to remember something the user told you before,
    their preferences, past conversations, or context.

    Args:
        user_id: The authenticated user's ID.
        query: What you're trying to remember (e.g. "user's exercise preferences").
        category: Filter by category. Use empty string for all categories.
        limit: Max number of memories to recall. Use 5 as a reasonable default.

    Returns:
        Dict with found status and list of memories.
    """
    memories = _memory_service.search(
        user_id, query, top_k=limit, category=category or None,
    )
    if not memories:
        return {"found": False, "message": "No matching memories found"}
    return {
        "found": True,
        "count": len(memories),
        "memories": [
            {
                "content": m.get("content", ""),
                "category": m.get("category", "fact"),
                "importance": m.get("importance", "medium"),
                "score": round(m.get("score", 0), 2),
                "createdAt": m.get("createdAt", ""),
            }
            for m in memories
        ],
    }
