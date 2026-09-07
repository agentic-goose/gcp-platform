variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "github_org_id" {
  description = "Numeric GitHub organization ID (WIF attribute_condition)"
  type        = string
}

variable "github_infra_repo_id" {
  description = "Numeric GitHub repository ID for the infra repo allowed to impersonate terraform-ci"
  type        = string
}

variable "terraform_state_bucket" {
  description = "Existing GCS bucket used for Terraform state. Create the bucket out of band (chicken-and-egg with remote state)."
  type        = string
}

variable "extra_services" {
  description = "Additional APIs to enable beyond the platform baseline (e.g. sqladmin.googleapis.com)"
  type        = set(string)
  default     = []
}

variable "extra_ci_roles" {
  description = "Additional project roles for terraform-ci beyond the platform baseline"
  type        = set(string)
  default     = []
}
