# Jumns ADK Agent Service — Google Cloud Run Deployment
# Terraform IaC for provisioning all GCP resources

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.23"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# --- Enable Required APIs ---

resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudbuild.googleapis.com",
    "firestore.googleapis.com",
    "aiplatform.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

# --- Artifact Registry (Docker image repository) ---

resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "jumns-repo"
  description   = "Docker images for Jumns ADK backend"
  format        = "DOCKER"
  depends_on    = [google_project_service.apis]
}

# --- Secret Manager ---

# --- IAM Service Account (Cloud Run runtime identity) ---

resource "google_service_account" "runner" {
  account_id   = "jumns-runner-${var.stage}"
  display_name = "Jumns Cloud Run Runner (${var.stage})"
}

# --- Firestore (default database for app data) ---

resource "google_firestore_database" "main" {
  name                        = "(default)"
  location_id                 = var.region
  type                        = "FIRESTORE_NATIVE"
  delete_protection_state     = "DELETE_PROTECTION_ENABLED"
  deletion_policy             = "ABANDON"
  depends_on                  = [google_project_service.apis]
}

resource "google_project_iam_member" "runner_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.runner.email}"
}

# --- GCS Bucket (uploads + memory vectors) ---

resource "google_storage_bucket" "uploads" {
  name          = "${var.project_id}-jumns-uploads-${var.stage}"
  location      = var.region
  force_destroy = var.stage == "dev" ? true : false

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition { age = 365 }
    action { type = "Delete" }
  }

  cors {
    origin          = var.allowed_cors_origins
    method          = ["GET", "PUT", "POST"]
    response_header = ["Content-Type"]
    max_age_seconds = 3600
  }

  depends_on = [google_project_service.apis]
}

resource "google_storage_bucket_iam_member" "runner_gcs" {
  bucket = google_storage_bucket.uploads.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.runner.email}"
}

# --- Firebase Auth IAM (token verification) ---

resource "google_project_iam_member" "runner_firebase_auth" {
  project = var.project_id
  role    = "roles/firebaseauth.viewer"
  member  = "serviceAccount:${google_service_account.runner.email}"
}

# --- Vertex AI IAM (Gemini model access via ADC) ---

resource "google_project_iam_member" "runner_vertex_ai" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.runner.email}"
}

# --- Cloud Run v2 Service ---

resource "google_cloud_run_v2_service" "backend" {
  name     = "jumns-backend-${var.stage}"
  location = var.region

  template {
    service_account = google_service_account.runner.email

    session_affinity = true

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/jumns-repo/jumns-backend:${var.image_tag}"

      ports {
        container_port = 8080
      }

      env {
        name  = "GOOGLE_GENAI_USE_VERTEXAI"
        value = "TRUE"
      }

      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }

      env {
        name  = "GOOGLE_CLOUD_LOCATION"
        value = var.region
      }

      env {
        name  = "FIREBASE_PROJECT_ID"
        value = "jems-dd018"  # Firebase project ID (NOT the GCP project ID)
      }

      env {
        name  = "MEMORY_BUCKET"
        value = google_storage_bucket.uploads.name
      }

      env {
        name  = "UPLOAD_BUCKET"
        value = google_storage_bucket.uploads.name
      }

      env {
        name  = "JUMNS_A2A_BASE_URL"
        value = ""  # Set post-deploy via gcloud or read from GOOGLE_CLOUD_RUN_SERVICE_URL at runtime
      }

      env {
        name  = "ALLOWED_ORIGINS"
        value = "*"  # Restrict to your Flutter app's domain in production
      }

      env {
        name = "SCHEDULER_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.scheduler_secret.secret_id
            version = "latest"
          }
        }
      }

      resources {
        limits = {
          cpu    = "2"
          memory = "2Gi"
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 5
    }

    timeout = "3600s"
  }

  depends_on = [
    google_secret_manager_secret_iam_member.runner_scheduler_secret_access,
    google_project_iam_member.runner_vertex_ai,
    google_artifact_registry_repository.repo,
    google_storage_bucket.uploads,
  ]
}

# --- Public Access (allUsers invoker) ---

resource "google_cloud_run_v2_service_iam_member" "public" {
  name     = google_cloud_run_v2_service.backend.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# --- Post-deploy: set JUMNS_A2A_BASE_URL to actual Cloud Run URI ---

resource "null_resource" "set_a2a_url" {
  triggers = {
    service_uri = google_cloud_run_v2_service.backend.uri
  }

  provisioner "local-exec" {
    command = "gcloud run services update ${google_cloud_run_v2_service.backend.name} --region=${var.region} --update-env-vars=JUMNS_A2A_BASE_URL=${google_cloud_run_v2_service.backend.uri} --quiet"
  }

  depends_on = [google_cloud_run_v2_service.backend]
}

# --- Scheduler Secret (Secret Manager) ---

resource "google_secret_manager_secret" "scheduler_secret" {
  secret_id = "jumns-scheduler-secret-${var.stage}"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "scheduler_secret_value" {
  secret      = google_secret_manager_secret.scheduler_secret.id
  secret_data = var.scheduler_secret
}

resource "google_secret_manager_secret_iam_member" "runner_scheduler_secret_access" {
  secret_id = google_secret_manager_secret.scheduler_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runner.email}"
}

# --- Cloud Scheduler (proactive agent jobs) ---

resource "google_project_service" "scheduler_api" {
  service            = "cloudscheduler.googleapis.com"
  disable_on_destroy = false
}

resource "google_service_account" "scheduler" {
  account_id   = "jumns-scheduler-${var.stage}"
  display_name = "Jumns Cloud Scheduler Invoker (${var.stage})"
}

resource "google_cloud_run_v2_service_iam_member" "scheduler_invoker" {
  name     = google_cloud_run_v2_service.backend.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

locals {
  backend_url = google_cloud_run_v2_service.backend.uri
  scheduler_jobs = {
    morning_briefing     = { schedule = "0 7 * * *",     description = "Daily morning briefing with schedule overview" }
    evening_journal      = { schedule = "0 21 * * *",    description = "Evening journal prompt based on the day's activity" }
    reminder_check       = { schedule = "*/5 * * * *",   description = "Check for due reminders" }
    plan_review          = { schedule = "0 18 * * *",    description = "Review goal progress and adapt plans" }
    smart_suggestions    = { schedule = "0 10,15 * * *", description = "Generate proactive suggestions" }
    memory_consolidation = { schedule = "0 3 * * *",     description = "Consolidate memory patterns (off-peak)" }
    goal_nudge           = { schedule = "0 12 * * *",    description = "Nudge stalled goals" }
  }
}

resource "google_cloud_scheduler_job" "proactive" {
  for_each = local.scheduler_jobs

  name        = "jumns-${each.key}-${var.stage}"
  description = each.value.description
  schedule    = each.value.schedule
  time_zone   = "UTC"
  region      = var.region

  http_target {
    http_method = "POST"
    uri         = "${local.backend_url}/api/scheduler/${each.key}"

    headers = {
      "Authorization" = "Bearer ${var.scheduler_secret}"
      "Content-Type"  = "application/json"
    }

    oidc_token {
      service_account_email = google_service_account.scheduler.email
      audience              = local.backend_url
    }
  }

  retry_config {
    retry_count          = 1
    min_backoff_duration = "5s"
    max_backoff_duration = "30s"
  }

  depends_on = [
    google_project_service.scheduler_api,
    google_cloud_run_v2_service.backend,
  ]
}

# --- Firestore TTL Policy ---
# NOTE: TTL on subcollections (users/{userId}/agent_context) must be configured
# via gcloud CLI or Firebase console, not Terraform (template paths unsupported).
# Run: gcloud firestore fields ttls update expireAt --collection-group=agent_context --enable-ttl
