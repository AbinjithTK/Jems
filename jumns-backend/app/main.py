"""Jumns API — FastAPI application with Cloud Run / Mangum handler.

Local dev: set DEV_MODE=true + FIRESTORE_EMULATOR_HOST=localhost:8080
to run with local Firestore emulator and skip auth.
"""

from __future__ import annotations

import json
import logging
import os
import sys
import time

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

try:
    from mangum import Mangum
except ImportError:
    Mangum = None  # Not needed for local dev

from app.exceptions import (
    AgentUnavailableError,
    RateLimitExceededError,
    ResourceNotFoundError,
    UnauthorizedError,
)

DEV_MODE = os.getenv("DEV_MODE", "").lower() in ("true", "1", "yes")

# ---------------------------------------------------------------------------
# Structured logging — JSON format for Cloud Run, plain for local dev
# ---------------------------------------------------------------------------


class _CloudRunFormatter(logging.Formatter):
    """Emit JSON lines compatible with Cloud Logging structured logs."""

    _LEVEL_MAP = {
        "DEBUG": "DEBUG",
        "INFO": "INFO",
        "WARNING": "WARNING",
        "ERROR": "ERROR",
        "CRITICAL": "CRITICAL",
    }

    def format(self, record: logging.LogRecord) -> str:
        entry = {
            "severity": self._LEVEL_MAP.get(record.levelname, "DEFAULT"),
            "message": record.getMessage(),
            "logger": record.name,
            "timestamp": self.formatTime(record, datefmt="%Y-%m-%dT%H:%M:%S.%fZ"),
        }
        if record.exc_info and record.exc_info[1]:
            entry["exception"] = self.formatException(record.exc_info)
        return json.dumps(entry, default=str)


def _configure_logging() -> None:
    handler = logging.StreamHandler(sys.stdout)
    if DEV_MODE:
        handler.setFormatter(logging.Formatter("%(levelname)s  %(name)s  %(message)s"))
    else:
        handler.setFormatter(_CloudRunFormatter())
    logging.root.handlers = [handler]
    logging.root.setLevel(logging.INFO)


_configure_logging()
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Jumns API",
    docs_url="/docs" if DEV_MODE else None,
    redoc_url=None,
)

# ---------------------------------------------------------------------------
# CORS — configurable via ALLOWED_ORIGINS env var (comma-separated)
# Defaults to permissive in dev, restrictive in production.
# ---------------------------------------------------------------------------
_default_origins = "*" if DEV_MODE else ""
_allowed_origins_raw = os.getenv("ALLOWED_ORIGINS", _default_origins)
_allowed_origins = (
    ["*"]
    if _allowed_origins_raw.strip() == "*"
    else [o.strip() for o in _allowed_origins_raw.split(",") if o.strip()]
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Demo-Mode"],
)

# Auth middleware — validates Firebase ID token, sets request.state.user_id
from app.middleware.auth import FirebaseAuthMiddleware

app.add_middleware(FirebaseAuthMiddleware)


# ---------------------------------------------------------------------------
# Request logging middleware — structured request/response logs for Cloud Run
# ---------------------------------------------------------------------------

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration_ms = round((time.time() - start) * 1000)
    logger.info(
        "%s %s → %d (%dms)",
        request.method,
        request.url.path,
        response.status_code,
        duration_ms,
    )
    return response

# ---------------------------------------------------------------------------
# Global exception handlers
# ---------------------------------------------------------------------------

@app.exception_handler(ResourceNotFoundError)
async def not_found_handler(_request: Request, exc: ResourceNotFoundError):
    return JSONResponse(status_code=404, content={"error": "Resource not found"})


@app.exception_handler(UnauthorizedError)
async def unauthorized_handler(_request: Request, exc: UnauthorizedError):
    return JSONResponse(status_code=401, content={"error": "Unauthorized"})


@app.exception_handler(RateLimitExceededError)
async def rate_limit_handler(_request: Request, exc: RateLimitExceededError):
    return JSONResponse(
        status_code=429,
        content={"error": "Daily message limit reached. Upgrade to Pro for unlimited messages."},
    )


@app.exception_handler(AgentUnavailableError)
async def agent_unavailable_handler(_request: Request, exc: AgentUnavailableError):
    return JSONResponse(
        status_code=503,
        content={"error": "AI service temporarily unavailable"},
    )


@app.exception_handler(RequestValidationError)
async def validation_handler(_request: Request, exc: RequestValidationError):
    return JSONResponse(status_code=422, content={"error": str(exc)})


@app.exception_handler(Exception)
async def generic_handler(_request: Request, exc: Exception):
    logger.exception("Unhandled exception: %s", exc)
    return JSONResponse(status_code=500, content={"error": "Internal server error"})


# ---------------------------------------------------------------------------
# Health check (unauthenticated)
# ---------------------------------------------------------------------------

@app.get("/health")
async def health_check():
    return {"status": "ok"}


# ---------------------------------------------------------------------------
# Route registration — imported lazily so missing deps don't crash on import
# ---------------------------------------------------------------------------

def _register_routes() -> None:
    """Import and register all route modules."""
    from app.routes import (
        access_code,
        agent_actions,
        chat,
        connections,
        goals,
        insights,
        journal,
        memories,
        messages,
        reminders,
        scheduler,
        settings,
        skills,
        subscription,
        tasks,
        upload,
    )

    # Chat router includes both REST (/api/chat) and WebSocket (/api/ws/chat)
    # All under /api prefix — Flutter client connects to /api/ws/chat/{user_id}/{session_id}
    app.include_router(chat.router, prefix="/api")
    app.include_router(connections.router, prefix="/api")

    for router_module in [
        messages,
        goals,
        tasks,
        reminders,
        skills,
        settings,
        subscription,
        access_code,
        insights,
        memories,
        upload,
        agent_actions,
        journal,
        scheduler,
    ]:
        app.include_router(router_module.router, prefix="/api")


_register_routes()

# ---------------------------------------------------------------------------
# Startup — verify Firestore connectivity
# ---------------------------------------------------------------------------

@app.on_event("startup")
async def _startup():
    """Verify Firestore connectivity on startup."""
    emulator = os.getenv("FIRESTORE_EMULATOR_HOST")
    if emulator:
        logger.info("FIRESTORE_EMULATOR_HOST=%s — using Firestore emulator", emulator)
    else:
        logger.info("Connecting to Firestore with Application Default Credentials")

    # Warm up the Firestore client
    try:
        from app.db.connection import get_firestore_client
        client = get_firestore_client()
        logger.info("Firestore client initialized for project: %s", client.project)
    except Exception as exc:
        logger.warning("Firestore connection check failed: %s", exc)

# ---------------------------------------------------------------------------
# Cloud Run / Lambda entry point
# ---------------------------------------------------------------------------

handler = Mangum(app) if Mangum else None
