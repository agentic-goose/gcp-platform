output "service_name" {
  value = google_cloud_run_v2_service.this.name
}

output "uri" {
  value = google_cloud_run_v2_service.this.uri
}

output "location" {
  value = google_cloud_run_v2_service.this.location
}

output "runtime_service_account" {
  value = google_service_account.runtime.email
}

output "deploy_service_account" {
  value = google_service_account.deploy.email
}
