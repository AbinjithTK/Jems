#!/usr/bin/env bash
# Jumns ADK Backend — Build, Push, and Deploy to Google Cloud Run
# Usage: ./deploy.sh <project-id> [region] [stage]
#
# Prerequisites:
#   - Docker installed and running
#   - gcloud CLI authenticated (gcloud auth login)
#   - Terraform >= 1.5 installed
#   - TF_VAR_scheduler_secret env var set

set -euo pipefail

PROJECT="${1:?Usage: ./deploy.sh <project-id> [region] [stage]}"
REGION="${2:-us-central1}"
STAGE="${3:-dev}"
TAG="${STAGE}-$(git rev-parse --short HEAD)"
IMAGE="${REGION}-docker.pkg.dev/${PROJECT}/jumns-repo/jumns-backend:${TAG}"

echo "=== Jumns Deploy ==="
echo "Project: ${PROJECT}"
echo "Region:  ${REGION}"
echo "Stage:   ${STAGE}"
echo "Tag:     ${TAG}"
echo ""

# 1. Build Docker image
echo "Building image: ${IMAGE}"
docker build -t "${IMAGE}" -f ../jumns-backend/Dockerfile ../jumns-backend/

# 2. Configure Docker auth for Artifact Registry
echo "Configuring Docker auth..."
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

# 3. Push image
echo "Pushing image..."
docker push "${IMAGE}"

# 4. Terraform apply
echo "Applying Terraform..."
terraform apply -auto-approve \
  -var="project_id=${PROJECT}" \
  -var="region=${REGION}" \
  -var="stage=${STAGE}" \
  -var="image_tag=${TAG}" \
  -var="scheduler_secret=${TF_VAR_scheduler_secret:?Set TF_VAR_scheduler_secret}"

SERVICE_URL="$(terraform output -raw service_url)"

echo ""
echo "=== Deploy Complete ==="
echo "Service URL:    ${SERVICE_URL}"
echo "Upload Bucket:  $(terraform output -raw upload_bucket_name)"
echo "Firestore DB:   $(terraform output -raw firestore_database)"
echo ""
echo "Flutter build command:"
echo "  flutter build apk --dart-define=API_BASE_URL=${SERVICE_URL} --dart-define=CHAT_BASE_URL=${SERVICE_URL}"
