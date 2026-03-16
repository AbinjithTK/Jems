@echo off
REM ============================================================
REM  Jumns Backend — Local Development Server (Firestore + ADK)
REM
REM  Prerequisites:
REM    1. Python 3.12+ with pip
REM    2. pip install -r requirements-local.txt
REM    3. gcloud auth application-default login
REM    4. set GEMINI_API_KEY=your-key
REM
REM  Connects directly to real Firestore (jems-dd018).
REM  DEV_MODE=true bypasses Firebase Auth only.
REM ============================================================

echo.
echo ========================================
echo   Jumns Backend — Local Dev (Firestore)
echo ========================================
echo.

set DEV_MODE=true
set DEV_USER_ID=demo-user
set GCP_PROJECT=jems-dd018
set FIREBASE_PROJECT_ID=jems-dd018
set GOOGLE_CLOUD_PROJECT=jems-dd018
set GCS_BUCKET=

echo Environment:
echo   DEV_MODE           = %DEV_MODE%
echo   DEV_USER_ID        = %DEV_USER_ID%
echo   GCP_PROJECT        = %GCP_PROJECT%
echo   Firestore          = LIVE (jems-dd018 via ADC)
echo   GEMINI_API_KEY     = %GEMINI_API_KEY%
echo.

if "%GEMINI_API_KEY%"=="" (
    echo WARNING: GEMINI_API_KEY not set - agent chat will fail.
    echo   set GEMINI_API_KEY=your-key-here
    echo.
)

echo Starting uvicorn on http://localhost:8000 ...
echo   Docs:   http://localhost:8000/docs
echo   Health: http://localhost:8000/health
echo.

python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload --log-level info
