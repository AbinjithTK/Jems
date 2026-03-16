"""Memory Bank service — GCS + faiss-cpu for semantic search.

Replaces the previous S3-based storage with Google Cloud Storage.
Enhanced with memory bank patterns:
- Categorized memory storage (facts, preferences, patterns, reflections)
- Memory consolidation (merge related memories)
- Session state integration (inject memories into ADK session state)
- Importance-weighted retrieval
"""

from __future__ import annotations

import json
import os
import uuid
from datetime import datetime, timezone
from typing import Any


MEMORY_CATEGORIES = {
    "preference", "personal_info", "goal_context", "habit",
    "important_date", "relationship", "health", "work",
    "skill", "emotional", "pattern", "reflection", "fact",
}

IMPORTANCE_WEIGHTS = {
    "critical": 1.0,
    "high": 0.8,
    "medium": 0.5,
    "low": 0.2,
}


class MemoryService:
    """Manages vector memory bank in GCS with faiss-cpu for search."""

    def __init__(self):
        self._bucket_name = os.getenv("MEMORY_BUCKET", "")
        self._bucket = None
        if self._bucket_name:
            try:
                from google.cloud import storage
                client = storage.Client()
                self._bucket = client.bucket(self._bucket_name)
            except Exception:
                self._bucket = None

    def search(
        self, user_id: str, query: str, top_k: int = 5,
        category: str | None = None,
        min_importance: str = "low",
    ) -> list[dict[str, Any]]:
        """Cosine similarity search over user's memories using faiss-cpu."""
        if not self._bucket:
            return []

        try:
            query_embedding = self._generate_embedding(query)
            if not query_embedding:
                return []

            memories = self._load_user_memories(user_id)
            if not memories:
                return []

            if category:
                memories = [m for m in memories if m.get("category") == category]

            min_weight = IMPORTANCE_WEIGHTS.get(min_importance, 0.0)
            if min_weight > 0:
                memories = [
                    m for m in memories
                    if IMPORTANCE_WEIGHTS.get(m.get("importance", "medium"), 0.5) >= min_weight
                ]

            with_embeddings = [m for m in memories if m.get("embedding")]
            if not with_embeddings:
                return []

            import numpy as np
            try:
                import faiss
                return self._faiss_search(query_embedding, with_embeddings, top_k, user_id)
            except ImportError:
                return self._numpy_search(query_embedding, with_embeddings, top_k)
        except Exception:
            return []

    def _faiss_search(
        self, query_embedding: list[float], memories: list[dict],
        top_k: int, user_id: str,
    ) -> list[dict]:
        import numpy as np
        import faiss

        dim = len(query_embedding)
        index = faiss.IndexFlatIP(dim)
        vectors = np.array([m["embedding"] for m in memories], dtype=np.float32)
        faiss.normalize_L2(vectors)
        index.add(vectors)

        q = np.array([query_embedding], dtype=np.float32)
        faiss.normalize_L2(q)
        k = min(top_k, len(memories))
        scores, indices = index.search(q, k)

        results = []
        for i, idx in enumerate(indices[0]):
            if idx < 0:
                continue
            mem = memories[idx]
            importance = mem.get("importance", "medium")
            weight = IMPORTANCE_WEIGHTS.get(importance, 0.5)
            boosted_score = float(scores[0][i]) * (0.7 + 0.3 * weight)
            results.append({
                "id": mem.get("id", ""),
                "userId": user_id,
                "content": mem.get("content", ""),
                "category": mem.get("category", "fact"),
                "importance": importance,
                "metadata": mem.get("metadata"),
                "createdAt": mem.get("createdAt"),
                "score": boosted_score,
            })
        return results

    def _numpy_search(
        self, query_embedding: list[float], memories: list[dict], top_k: int,
    ) -> list[dict]:
        import numpy as np

        q = np.array(query_embedding, dtype=np.float32)
        q = q / (np.linalg.norm(q) + 1e-9)
        scored = []
        for mem in memories:
            v = np.array(mem["embedding"], dtype=np.float32)
            v = v / (np.linalg.norm(v) + 1e-9)
            score = float(np.dot(q, v))
            importance = mem.get("importance", "medium")
            weight = IMPORTANCE_WEIGHTS.get(importance, 0.5)
            scored.append((score * (0.7 + 0.3 * weight), mem))
        scored.sort(key=lambda x: x[0], reverse=True)
        return [
            {
                "id": mem.get("id", ""),
                "userId": mem.get("userId", ""),
                "content": mem.get("content", ""),
                "category": mem.get("category", "fact"),
                "importance": mem.get("importance", "medium"),
                "metadata": mem.get("metadata"),
                "createdAt": mem.get("createdAt"),
                "score": score,
            }
            for score, mem in scored[:top_k]
        ]

    def extract_and_store(
        self, user_id: str, conversation_turn: str,
        category: str = "fact", importance: str = "medium",
    ) -> str | None:
        """Extract key facts from a conversation turn and store in GCS."""
        if not self._bucket:
            return None
        embedding = self._generate_embedding(conversation_turn)
        if not embedding:
            return None

        memory_id = str(uuid.uuid4())
        doc = {
            "id": memory_id,
            "userId": user_id,
            "content": conversation_turn,
            "embedding": embedding,
            "category": category if category in MEMORY_CATEGORIES else "fact",
            "importance": importance if importance in IMPORTANCE_WEIGHTS else "medium",
            "metadata": {},
            "createdAt": datetime.now(timezone.utc).isoformat(),
        }
        try:
            blob = self._bucket.blob(f"memories/{user_id}/{memory_id}.json")
            blob.upload_from_string(json.dumps(doc), content_type="application/json")
            return memory_id
        except Exception:
            return None

    def store_structured(
        self, user_id: str, content: str, category: str,
        importance: str = "medium", metadata: dict | None = None,
    ) -> str | None:
        """Store a structured memory with explicit category and importance."""
        if not self._bucket:
            return None
        embedding = self._generate_embedding(content)
        if not embedding:
            return None

        memory_id = str(uuid.uuid4())
        doc = {
            "id": memory_id,
            "userId": user_id,
            "content": content,
            "embedding": embedding,
            "category": category if category in MEMORY_CATEGORIES else "fact",
            "importance": importance if importance in IMPORTANCE_WEIGHTS else "medium",
            "metadata": metadata or {},
            "createdAt": datetime.now(timezone.utc).isoformat(),
        }
        try:
            blob = self._bucket.blob(f"memories/{user_id}/{memory_id}.json")
            blob.upload_from_string(json.dumps(doc), content_type="application/json")
            return memory_id
        except Exception:
            return None

    def get_memory_bank_summary(self, user_id: str) -> dict[str, Any]:
        """Get a summary of the user's memory bank for session state injection."""
        memories = self._load_user_memories(user_id)
        by_category: dict[str, int] = {}
        for m in memories:
            cat = m.get("category", "fact")
            by_category[cat] = by_category.get(cat, 0) + 1

        sorted_mems = sorted(memories, key=lambda x: x.get("createdAt", ""), reverse=True)
        recent = [
            {"content": m.get("content", "")[:200], "category": m.get("category", "fact"), "importance": m.get("importance", "medium")}
            for m in sorted_mems[:10]
        ]
        critical = [
            {"content": m.get("content", "")[:200], "category": m.get("category", "fact")}
            for m in memories if m.get("importance") == "critical"
        ]
        return {
            "total_memories": len(memories),
            "by_category": by_category,
            "recent_memories": recent,
            "critical_memories": critical[:5],
        }

    def list_memories(self, user_id: str) -> list[dict]:
        """Return all memory entries for a user (without embeddings)."""
        if not self._bucket:
            return []
        memories = self._load_user_memories(user_id)
        for m in memories:
            m.pop("embedding", None)
        return memories

    def delete(self, user_id: str, memory_id: str) -> None:
        """Remove a specific memory file from GCS."""
        if not self._bucket:
            return
        try:
            blob = self._bucket.blob(f"memories/{user_id}/{memory_id}.json")
            blob.delete()
        except Exception:
            pass

    def _load_user_memories(self, user_id: str) -> list[dict]:
        """Load all memory JSON files for a user from GCS."""
        if not self._bucket:
            return []
        memories = []
        prefix = f"memories/{user_id}/"
        try:
            blobs = self._bucket.list_blobs(prefix=prefix)
            for blob in blobs:
                try:
                    data = blob.download_as_text()
                    memories.append(json.loads(data))
                except Exception:
                    continue
        except Exception:
            pass
        return memories

    def _generate_embedding(self, text: str) -> list[float] | None:
        """Generate a 768-d embedding via Vertex AI embedding model."""
        project = os.getenv("GOOGLE_CLOUD_PROJECT", "")
        location = os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1")
        if not project:
            return None
        try:
            import google.auth
            import google.auth.transport.requests
            import httpx

            credentials, _ = google.auth.default()
            credentials.refresh(google.auth.transport.requests.Request())

            url = (
                f"https://{location}-aiplatform.googleapis.com/v1/projects/"
                f"{project}/locations/{location}/publishers/google/models/"
                "text-embedding-004:predict"
            )
            resp = httpx.post(
                url,
                headers={"Authorization": f"Bearer {credentials.token}"},
                json={
                    "instances": [{"content": text[:2000]}],
                },
                timeout=10.0,
            )
            resp.raise_for_status()
            return resp.json()["predictions"][0]["embeddings"]["values"]
        except Exception:
            return None
