"""Web search tool — internet access via Gemini's Google Search grounding.

Mirrors the Projectj web_search tool: uses Gemini's built-in Google Search
to provide real-time information for goal planning, tips, and research.

Uses Vertex AI with Application Default Credentials (ADC) on Cloud Run.
"""

from __future__ import annotations

import os


def _get_vertex_access_token() -> str:
    """Get an access token from ADC for Vertex AI REST calls."""
    import google.auth
    import google.auth.transport.requests

    credentials, _ = google.auth.default()
    credentials.refresh(google.auth.transport.requests.Request())
    return credentials.token


def web_search(query: str, context: str) -> dict:
    """Search the internet for real-time information using Google Search.

    Use when the user asks about current events, needs tips/advice,
    wants to research something for their goals, or when you need
    up-to-date information to help plan their achievement path.

    Examples:
    - "best training plan for half marathon beginners"
    - "how to learn Spanish in 6 months"
    - "healthy meal prep ideas for weight loss"

    Args:
        query: The search query to look up.
        context: Why you're searching — helps refine results. Use empty string if none.

    Returns:
        Dict with answer text and source URLs.
    """
    project = os.getenv("GOOGLE_CLOUD_PROJECT", "")
    location = os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1")
    if not project:
        return {"error": "Web search not configured — GOOGLE_CLOUD_PROJECT not set", "query": query}

    try:
        import httpx

        prompt = (
            f"Search the internet and provide a comprehensive answer about: {query}"
        )
        if context:
            prompt += f"\nContext: {context}"
        prompt += (
            "\n\nProvide specific, actionable information with key facts, "
            "tips, or data points. Include source references when possible."
        )

        token = _get_vertex_access_token()
        url = (
            f"https://{location}-aiplatform.googleapis.com/v1beta1/projects/"
            f"{project}/locations/{location}/publishers/google/models/"
            "gemini-2.5-flash:generateContent"
        )

        resp = httpx.post(
            url,
            headers={"Authorization": f"Bearer {token}"},
            json={
                "contents": [{"parts": [{"text": prompt}]}],
                "tools": [{"google_search": {}}],
                "generationConfig": {"maxOutputTokens": 2048},
            },
            timeout=30.0,
        )
        resp.raise_for_status()
        data = resp.json()

        text = ""
        candidates = data.get("candidates", [])
        if candidates:
            parts = candidates[0].get("content", {}).get("parts", [])
            text = " ".join(p.get("text", "") for p in parts)

        # Extract grounding sources
        grounding = candidates[0].get("groundingMetadata", {}) if candidates else {}
        chunks = grounding.get("groundingChunks", [])
        sources = [
            {"title": c.get("web", {}).get("title", ""), "url": c.get("web", {}).get("uri", "")}
            for c in chunks[:5]
        ]

        return {"answer": text or "No results found.", "sources": sources, "query": query}

    except Exception as e:
        return {"error": f"Web search failed: {str(e)}", "query": query}
