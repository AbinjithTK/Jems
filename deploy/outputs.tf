output "service_url" {
  description = "Cloud Run service URL"
  value       = google_cloud_run_v2_service.backend.uri
}

output "service_account_email" {
  description = "Cloud Run service account email"
  value       = google_service_account.runner.email
}

output "artifact_registry_url" {
  description = "Artifact Registry URL for docker push"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/jumns-repo"
}

output "firestore_database" {
  description = "Firestore database name"
  value       = google_firestore_database.main.name
}

output "upload_bucket_name" {
  description = "GCS bucket name for uploads and memory vectors"
  value       = google_storage_bucket.uploads.name
}

output "upload_bucket_url" {
  description = "GCS bucket URL"
  value       = google_storage_bucket.uploads.url
}

output "scheduler_service_account" {
  description = "Cloud Scheduler service account email"
  value       = google_service_account.scheduler.email
}

output "scheduler_job_names" {
  description = "Cloud Scheduler job names"
  value       = [for k, v in google_cloud_scheduler_job.proactive : v.name]
}
