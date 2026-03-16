# Jumns ADK Backend — Google Cloud Deployment

Terraform IaC for deploying the Jumns multi-agent backend to Google Cloud Run.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) authenticated (`gcloud auth login`)
- [Docker](https://docs.docker.com/get-docker/)
- A GCP project with billing enabled

## Resources Provisioned

| Resource | Purpose |
|----------|---------|
| Artifact Registry | Docker image repository (`jumns-repo`) |
| Cloud Run v2 Service | FastAPI + ADK agent service (WebSocket enabled) |
| Secret Manager | Scheduler secret |
| Firestore (default) | App data (users, mes
sages, goals, tasks, journal) |
| GCS Bucket | File uploads + memory vectors |
| Cloud Scheduler | 7 proactive agent jobs (briefings, reminders, etc.) |
| IAM Service Accounts | Cloud Run runner + Scheduler invoker |
| Vertex AI IAM | Gemini model access via ADC (no API key needed) |

## Quick Start

```bash
cd deploy/

# 1. Initialize Terraform
terraform init

# 2. Set secrets (never commit these)
export TF_VAR_scheduler_secret="$(openssl rand -hex 32)"

# 3. Deploy (builds image + pushes + applies Terraform)
./deploy.sh my-gcp-project us-central1 dev
```

## Manual Deploy

```bash
cd deploy/

# Build and push image
TAG="dev-$(git rev-parse --short HEAD)"
IMAGE="us-central1-docker.pkg.dev/my-project/jumns-repo/jumns-backend:${TAG}"
docker build -t $IMAGE -f ../jumns-backend/Dockerfile ../jumns-backend/
gcloud auth configure-docker us-central1-docker.pkg.dev --quiet
docker push $IMAGE

# Set secrets
export TF_VAR_scheduler_secret="$(openssl rand -hex 32)"

# Apply Terraform
terraform apply \
  -var="project_id=my-project" \
  -var="region=us-central1" \
  -var="stage=dev" \
  -var="image_tag=${TAG}" \
  -var="scheduler_secret=${TF_VAR_scheduler_secret}"
```

## Flutter App Connection

After deploy, build the Flutter app with the Cloud Run URL:

```bash
SERVICE_URL="$(cd deploy && terraform output -raw service_url)"

flutter build apk \
  --dart-define=API_BASE_URL=${SERVICE_URL} \
  --dart-define=CHAT_BASE_URL=${SERVICE_URL}
```

Both `API_BASE_URL` and `CHAT_BASE_URL` point to the same Cloud Run service
(single backend serves REST + WebSocket).

## Environment Variables

| Variable | Source | Description |
|----------|--------|-------------|
| `GOOGLE_GENAI_USE_VERTEXAI` | Dockerfile | Enables Vertex AI for google-genai SDK |
| `GOOGLE_CLOUD_PROJECT` | Terraform | GCP project ID |
| `GOOGLE_CLOUD_LOCATION` | Terraform | Region (us-central1) |
| `SCHEDULER_SECRET` | Secret Manager | Shared secret for Cloud Scheduler auth |
| `FIREBASE_PROJECT_ID` | Terraform | Firebase project for auth token verification |
| `MEMORY_BUCKET` | Terraform | GCS bucket for memory vectors |
| `UPLOAD_BUCKET` | Terraform | GCS bucket for file uploads |
| `ALLOWED_ORIGINS` | Terraform | CORS origins (comma-separated, `*` for dev) |
| `JUMNS_A2A_BASE_URL` | Post-deploy | Cloud Run service URL (set automatically) |

## Architecture

```
Flutter App (Android)
  ├── REST  → Cloud Run /api/*  (CRUD, data)
  └── WSS  → Cloud Run /api/ws/chat/{user_id}/{session_id}
                    │
                    ├── Firebase Auth (ID token verification)
                    ├── Firestore (app data)
                    ├── GCS (uploads, memory)
                    ├── Vertex AI / Gemini (ADK agents)
                    └── Cloud Scheduler (proactive jobs)
```
