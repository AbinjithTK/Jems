#!/usr/bin/env bash
# ============================================================
#  Jumns Backend — Local Development Server (Firestore + ADK)
#
#  Prerequisites:
#    1. Python 3.12+ with pip
#    2. pip install -r requirements-local.txt
#    3. gcloud auth application-default login
#    4. export GEMINI_API_KEY=your-key
#
#  Connects directly to real Firestore (jems-dd018).
#  DEV_MODE=true bypasses Firebase Auth only.
# ============================================================

set -e

echo ""
echo "========================================"
echo "  Jumns Backend — Local Dev (Firestore)"
echo "========================================"
echo ""

# --- Environment variables ---
export DEV_MODE=true
export DEV_USER_ID=demo-user
export GCP_PROJECT=jems-dd018
export FIREBASE_PROJECT_ID=jems-dd018
export GOOGLE_CLOUD_PROJECT=jems-dd018

# Gemini API key (required for agent chat)
export GEMINI_API_KEY="${GEMINI_API_KEY:-}"
export GOOGLE_API_KEY="${GOOGLE_API_KEY:-$GEMINI_API_KEY}"

# GCS bucket — leave empty for local dev (uploads will fail gracefully)
export GCS_BUCKET=

echo "Environment:"
echo "  DEV_MODE           = $DEV_MODE"
echo "  DEV_USER_ID        = $DEV_USER_ID"
echo "  GCP_PROJECT        = $GCP_PROJECT"
echo "  Firestore          = LIVE (jems-dd018 via ADC)"
echo "  GEMINI_API_KEY     = ${GEMINI_API_KEY:+(set)}${GEMINI_API_KEY:-(NOT SET)}"
echo ""

if [ -z "$GEMINI_API_KEY" ]; then
    echo "⚠  GEMINI_API_KEY not set — agent chat will fail."
    echo "   export GEMINI_API_KEY=your-key-here"
    echo ""
fi

echo "Starting uvicorn on http://localhost:8000 ..."
echo "  Docs:   http://localhost:8000/docs"
echo "  Health: http://localhost:8000/health"
echo ""

python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload --log-level info
