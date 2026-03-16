"""Repository for access_codes collection — Firestore.

Top-level collection (not a subcollection) with 'code' as document ID.
Uses Firestore transactions for atomic activate.
"""

from __future__ import annotations

from google.cloud import firestore

from app.db.base_repository import utc_now_iso
from app.db.connection import get_firestore_client
from app.db.table_config import ACCESS_CODES_COLLECTION


class AccessCodesRepository:
    def __init__(self):
        self._db = get_firestore_client()
        self._collection = self._db.collection(ACCESS_CODES_COLLECTION)

    def activate_code(self, user_id: str, code: str) -> bool:
        """Atomically activate a code. Returns True on success.

        Uses a Firestore transaction to ensure the code exists and
        hasn't already been used before marking it as used.
        """
        doc_ref = self._collection.document(code)

        @firestore.transactional
        def _activate(transaction: firestore.Transaction) -> bool:
            snapshot = doc_ref.get(transaction=transaction)
            if not snapshot.exists:
                return False
            data = snapshot.to_dict()
            if data.get("usedBy"):
                return False  # already used
            transaction.update(doc_ref, {
                "usedBy": user_id,
                "usedAt": utc_now_iso(),
            })
            return True

        try:
            return _activate(self._db.transaction())
        except Exception:
            return False

    def get_activation_status(self, user_id: str) -> bool:
        """Check if this user has activated any access code."""
        try:
            docs = (
                self._collection
                .where("usedBy", "==", user_id)
                .limit(1)
                .stream()
            )
            return any(True for _ in docs)
        except Exception:
            return False
