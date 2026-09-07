variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "name" {
  description = "Cloud Run service name"
  type        = string
}

variable "runtime_account_id" {
  description = "Service account ID (not email) for the runtime identity"
  type        = string
}

variable "deploy_account_id" {
  description = "Service account ID (not email) for GitHub deploys"
  type        = string
}

variable "wif_pool_name" {
  description = "Full Workload Identity Pool resource name from the bootstrap module"
  type        = string
}

variable "github_app_repo_id" {
  description = "Numeric GitHub repository ID allowed to impersonate the deploy SA"
  type        = string
}

variable "terraform_ci_service_account" {
  description = "terraform-ci SA email; granted serviceAccountUser on the runtime SA"
  type        = string
}

variable "artifact_registry_location" {
  type = string
}

variable "artifact_registry_repository" {
  type = string
}

variable "invoker_iam_disabled" {
  description = "If true, the service is publicly invokable (no IAM on invoke)"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "cpu" {
  type    = string
  default = "1"
}

variable "memory" {
  type    = string
  default = "512Mi"
}

variable "min_instance_count" {
  type    = number
  default = 0
}

variable "max_instance_count" {
  type    = number
  default = 1
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "vpc_network" {
  description = "VPC self-link for Direct VPC egress. Null skips VPC access."
  type        = string
  default     = null
}

variable "vpc_subnetwork" {
  type    = string
  default = null
}

variable "vpc_egress" {
  type    = string
  default = "PRIVATE_RANGES_ONLY"
}

variable "cloud_sql_instances" {
  description = "Cloud SQL instance connection names to mount at /cloudsql"
  type        = list(string)
  default     = []
}

variable "env" {
  description = "Seed env vars. CI typically owns later updates via ignore_changes."
  type        = map(string)
  default     = {}
}
