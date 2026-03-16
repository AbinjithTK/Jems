"""Firebase Auth token validation middleware.

Validates the Authorization: Bearer <token> header by verifying the
Firebase ID token against Google's public keys.  On success, sets
request.state.user_id to the Firebase UID.  Skips auth for GET /health.

Local dev: set DEV_MODE=true to bypass token validation entirely.
All requests get user_id = DEV_USER_ID (default "dev-user").
"""

from __future__ import annotations

import logging
import os
from typing import Any

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Dev mode — skip all token validation for local development
# ---------------------------------------------------------------------------
DEV_MODE = os.getenv("DEV_MODE", "").lower() in ("true", "1", "yes")
DEV_USER_ID = os.getenv("DEV_USER_ID", "dev-user")

# Demo mode — allows unauthenticated access via X-Demo-Mode header
# Separate from DEV_MODE so production can serve demo users safely
DEMO_MODE_ENABLED = os.getenv("DEMO_MODE_ENABLED", "").lower() in ("true", "1", "yes")
DEMO_USER_ID = "demo-user"

# Google's public keys for verifying Firebase ID tokens
_GOOGLE_CERTS_URL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"
_FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID", "jems-dd018")

def verify_firebase_token(token: str) -> dict[str, Any]:
    """Verify a Firebase ID token and return the decoded claims.

    Uses google.auth to verify the token signature against Google's
    public certificates, then validates issuer and audience.

    google.oauth2.id_token manages its own cert cache internally,
    so we just call it directly — no manual cert caching needed.
    """
    from google.auth.transport import requests as google_requests
    from google.oauth2 import id_token

    claims = id_token.verify_firebase_token(
        token,
        google_requests.Request(),
        audience=_FIREBASE_PROJECT_ID,
    )
    return claims


# Paths that skip authentication
_PUBLIC_PATHS = {"/health", "/docs", "/openapi.json"}

# Path prefixes that use their own auth (e.g. Cloud Scheduler shared secret)
_SKIP_AUTH_PREFIXES = ("/api/scheduler",)


class FirebaseAuthMiddleware(BaseHTTPMiddleware):
    """Starlette middleware that validates Firebase ID tokens on every request.

    When DEV_MODE=true, skips all token validation and sets a dummy user_id.
    """

    async def dispatch(self, request: Request, call_next):
        path = request.url.path

        # Skip auth for public endpoints
        if path in _PUBLIC_PATHS:
            return await call_next(request)

        # Skip auth for prefixes that handle their own authentication
        if any(path.startswith(p) for p in _SKIP_AUTH_PREFIXES):
            return await call_next(request)

        # OPTIONS requests (CORS preflight) pass through
        if request.method == "OPTIONS":
            return await call_next(request)

        # --- DEV MODE: bypass token validation, set dummy user_id ---
        if DEV_MODE:
            request.state.user_id = DEV_USER_ID
            return await call_next(request)

        # --- DEMO MODE: accept X-Demo-Mode header, set demo user_id ---
        if DEMO_MODE_ENABLED:
            demo_header = request.headers.get("x-demo-mode", "")
            if demo_header.lower() in ("true", "1"):
                request.state.user_id = DEMO_USER_ID
                return await call_next(request)

        auth_header = request.headers.get("authorization", "")
        if not auth_header.startswith("Bearer "):
            logger.warning(
                "Missing or malformed Authorization header on %s %s (got: %r)",
                request.method, path, auth_header[:20] if auth_header else "<empty>",
            )
            return JSONResponse(status_code=401, content={"error": "Missing or malformed Authorization header"})

        token = auth_header[7:]  # strip "Bearer "
        if not token:
            logger.warning("Empty Bearer token on %s %s", request.method, path)
            return JSONResponse(status_code=401, content={"error": "Empty Bearer token"})

        try:
            claims = verify_firebase_token(token)
        except Exception as exc:
            exc_str = str(exc)
            if "Token expired" in exc_str or "exp" in exc_str:
                logger.warning("Expired Firebase token on %s %s: %s", request.method, path, exc)
                return JSONResponse(status_code=401, content={"error": "Token expired"})
            logger.warning("Invalid Firebase token on %s %s: %s", request.method, path, exc)
            return JSONResponse(status_code=401, content={"error": "Invalid token"})

        # Firebase UID is in the 'sub' claim (same as 'user_id' in Firebase tokens)
        user_id = claims.get("sub") or claims.get("user_id")
        if not user_id:
            logger.warning("Token missing UID claims on %s %s", request.method, path)
            return JSONResponse(status_code=401, content={"error": "Token missing user ID"})

        # Attach user_id to request state — all route handlers read from here
        request.state.user_id = user_id
        return await call_next(request)
