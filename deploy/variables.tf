variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "us-central1"
}

variable "stage" {
  description = "Deployment stage (dev, prod)"
  type        = string
  default     = "dev"
}

variable "image_tag" {
  description = "Docker image tag (e.g. dev-abc1234)"
  type        = string
}

variable "scheduler_secret" {
  description = "Shared secret for Cloud Scheduler → backend auth"
  type        = string
  sensitive   = true
  default     = ""
}

variable "allowed_cors_origins" {
  description = "Allowed CORS origins for GCS upload bucket. Use [\"*\"] for dev, restrict in prod."
  type        = list(string)
  default     = ["*"]
}
