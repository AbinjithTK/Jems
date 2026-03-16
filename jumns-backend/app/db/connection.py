"""Google Cloud Firestore client — cached across requests.

Replaces the previous boto3 DynamoDB connection.
Uses FIRESTORE_EMULATOR_HOST env var for local development,
otherwise connects to the project's Firestore instance.
"""

from __future__ import annotations

import os

from google.cloud import firestore

_client: firestore.Client | None = None


def get_firestore_client() -> firestore.Client:
    """Return a cached Firestore client.

    If FIRESTORE_EMULATOR_HOST is set, connects to the local emulator.
    Otherwise uses Application Default Credentials (ADC).
    """
    global _client
    if _client is None:
        project = os.getenv("GCP_PROJECT", os.getenv("GOOGLE_CLOUD_PROJECT", "jems-dd018"))
        _client = firestore.Client(project=project)
    return _client


def get_collection(collection_name: str) -> firestore.CollectionReference:
    """Return a Firestore collection reference."""
    return get_firestore_client().collection(collection_name)
