"""Shared Firestore CRUD patterns used by all repositories.

Replaces the previous DynamoDB BaseRepository.
Uses subcollections under users/{userId}/ for per-user data.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any

from google.cloud import firestore

from app.db.connection import get_firestore_client
from app.exceptions import ResourceNotFoundError


def new_id() -> str:
    """Generate a UUID v4 string."""
    return str(uuid.uuid4())


def utc_now_iso() -> str:
    """Return current UTC time as ISO 8601 string."""
    return datetime.now(timezone.utc).isoformat()


class BaseRepository:
    """Thin wrapper around a Firestore subcollection with common operations.

    Most repositories store data as:
        users/{userId}/{subcollection_name}/{doc_id}
    """

    def __init__(self, subcollection_name: str):
        self._subcollection_name = subcollection_name
        self._db = get_firestore_client()

    def _user_collection(self, user_id: str) -> firestore.CollectionReference:
        """Return the subcollection ref for a given user."""
        return (
            self._db.collection("users")
            .document(user_id)
            .collection(self._subcollection_name)
        )

    # -- write ---------------------------------------------------------------

    def put_item(self, user_id: str, doc_id: str, item: dict[str, Any]) -> dict[str, Any]:
        """Create or overwrite a document."""
        try:
            self._user_collection(user_id).document(doc_id).set(item)
            return item
        except Exception as exc:
            raise RuntimeError(f"Firestore put_item failed: {exc}") from exc

    # -- read ----------------------------------------------------------------

    def get_item(self, user_id: str, doc_id: str) -> dict[str, Any]:
        """Get a single document by ID."""
        try:
            doc = self._user_collection(user_id).document(doc_id).get()
        except Exception as exc:
            raise RuntimeError(f"Firestore get_item failed: {exc}") from exc
        if not doc.exists:
            raise ResourceNotFoundError()
        return doc.to_dict()

    def query_by_user(
        self,
        user_id: str,
        *,
        order_by: str | None = "createdAt",
        descending: bool = False,
        limit: int | None = None,
        filters: list[tuple[str, str, Any]] | None = None,
    ) -> list[dict[str, Any]]:
        """Query all documents in a user's subcollection.

        When filters are present, sorting is done in Python to avoid
        requiring Firestore composite indexes. Firestore-level order_by
        is only used for unfiltered queries (single-field index suffices).

        Args:
            user_id: The user's ID.
            order_by: Field to sort by (None to skip ordering).
            descending: Sort descending if True.
            limit: Max number of results.
            filters: List of (field, op, value) tuples for .where() clauses.
        """
        try:
            ref = self._user_collection(user_id)
            if filters:
                for field, op, value in filters:
                    ref = ref.where(field, op, value)
                # Skip Firestore-level ordering when filters are present
                # to avoid composite index requirements. Sort in Python below.
            elif order_by:
                direction = (
                    firestore.Query.DESCENDING if descending
                    else firestore.Query.ASCENDING
                )
                ref = ref.order_by(order_by, direction=direction)
            if limit and not filters:
                # Only apply Firestore limit when not doing Python sort
                ref = ref.limit(limit)
            results = [doc.to_dict() for doc in ref.stream()]
            # Python-side sort when filters were used
            if filters and order_by:
                results.sort(
                    key=lambda d: d.get(order_by, ""),
                    reverse=descending,
                )
            if limit and filters:
                results = results[:limit]
            return results
        except Exception as exc:
            raise RuntimeError(f"Firestore query failed: {exc}") from exc

    # -- update --------------------------------------------------------------

    def update_item(
        self,
        user_id: str,
        doc_id: str,
        updates: dict[str, Any],
    ) -> dict[str, Any]:
        """Update specific fields on a document. Returns the full updated doc."""
        if not updates:
            return self.get_item(user_id, doc_id)
        try:
            doc_ref = self._user_collection(user_id).document(doc_id)
            doc_ref.update(updates)
            return doc_ref.get().to_dict()
        except Exception as exc:
            raise RuntimeError(f"Firestore update_item failed: {exc}") from exc

    # -- delete --------------------------------------------------------------

    def delete_item(self, user_id: str, doc_id: str) -> None:
        """Delete a single document."""
        try:
            self._user_collection(user_id).document(doc_id).delete()
        except Exception as exc:
            raise RuntimeError(f"Firestore delete_item failed: {exc}") from exc

    def batch_delete(self, user_id: str, doc_ids: list[str]) -> None:
        """Delete multiple documents in a batch."""
        try:
            batch = self._db.batch()
            col = self._user_collection(user_id)
            for doc_id in doc_ids:
                batch.delete(col.document(doc_id))
            batch.commit()
        except Exception as exc:
            raise RuntimeError(f"Firestore batch_delete failed: {exc}") from exc
