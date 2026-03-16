"""File upload route — stores proof images in GCS, returns URL."""

from __future__ import annotations

import os
import uuid

from fastapi import APIRouter, File, Form, Request, UploadFile

router = APIRouter(prefix="/upload", tags=["upload"])

_BUCKET_NAME = os.getenv("UPLOAD_BUCKET", os.getenv("MEMORY_BUCKET", ""))
_bucket = None


def _gcs_bucket():
    global _bucket
    if _bucket is None and _BUCKET_NAME:
        from google.cloud import storage
        _bucket = storage.Client().bucket(_BUCKET_NAME)
    return _bucket


@router.post("/proof")
async def upload_proof(
    request: Request,
    file: UploadFile = File(...),
    task_id: str = Form(""),
):
    """Upload a proof image for task completion.

    Stores in GCS under proofs/{user_id}/{uuid}.{ext} and returns the URL.
    """
    user_id = request.state.user_id
    ext = (file.filename or "image.jpg").rsplit(".", 1)[-1] or "jpg"
    key = f"proofs/{user_id}/{uuid.uuid4().hex}.{ext}"

    contents = await file.read()
    bucket = _gcs_bucket()

    if bucket:
        blob = bucket.blob(key)
        blob.upload_from_string(contents, content_type=file.content_type or "image/jpeg")
        url = f"https://storage.googleapis.com/{_BUCKET_NAME}/{key}"
    else:
        # Local dev fallback — save to /tmp
        local_path = f"/tmp/{key.replace('/', '_')}"
        with open(local_path, "wb") as f:
            f.write(contents)
        url = f"file://{local_path}"

    return {
        "url": url,
        "key": key,
        "taskId": task_id,
        "contentType": file.content_type or "image/jpeg",
        "size": len(contents),
    }
