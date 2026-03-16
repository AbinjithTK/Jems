#!/bin/bash
# Jumns Release APK Build Script
#
# Usage:
#   ./build_release.sh                    # Build APK (default)
#   ./build_release.sh --appbundle        # Build App Bundle (for Play Store)
#
# Required environment variables:
#   API_BASE_URL   - Google Cloud Run endpoint (REST + WebSocket)
#   CHAT_BASE_URL  - Google Cloud Run endpoint (same as API_BASE_URL)

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────

API_BASE_URL="${API_BASE_URL:-https://YOUR_CLOUD_RUN_URL.run.app}"
CHAT_BASE_URL="${CHAT_BASE_URL:-$API_BASE_URL}"

# ── Validation ─────────────────────────────────────────────────────────────

if [[ "$API_BASE_URL" == *"YOUR_"* ]]; then
  echo "ERROR: Set API_BASE_URL to your Cloud Run service URL."
  echo "  export API_BASE_URL=https://jumns-backend-dev-xxxxx-uc.a.run.app"
  exit 1
fi

# ── Check keystore ─────────────────────────────────────────────────────────

if [ ! -f "android/key.properties" ]; then
  echo "WARNING: android/key.properties not found. Building with debug signing."
  echo "  See android/key.properties.example for setup instructions."
  echo ""
fi

# ── Build ──────────────────────────────────────────────────────────────────

BUILD_TYPE="${1:---apk}"

DART_DEFINES=(
  "--dart-define=API_BASE_URL=$API_BASE_URL"
  "--dart-define=CHAT_BASE_URL=$CHAT_BASE_URL"
)

echo "Building Jumns release..."
echo "  API:  $API_BASE_URL"
echo "  Chat: $CHAT_BASE_URL"
echo ""

if [[ "$BUILD_TYPE" == "--appbundle" ]]; then
  flutter build appbundle --release "${DART_DEFINES[@]}"
  echo ""
  echo "App Bundle built: build/app/outputs/bundle/release/app-release.aab"
else
  flutter build apk --release "${DART_DEFINES[@]}"
  echo ""
  echo "APK built: build/app/outputs/flutter-apk/app-release.apk"
fi
