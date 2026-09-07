output "terraform_service_account" {
  value = google_service_account.terraform_ci.email
}

output "workload_identity_pool" {
  value = google_iam_workload_identity_pool.github.name
}

output "workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}

output "enabled_services" {
  value = local.services
}
