# Example thin root for a new GCP project. Copy into that project's infra
# repo. Do not apply from this repository.
#
# First apply of bootstrap is local (WIF does not exist yet):
#   terraform init && terraform apply
# Then set GitHub vars from outputs and switch CI to the reusable workflow.

terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }
}

variable "project_id" { type = string }
variable "region" { type = string }
variable "github_org_id" { type = string }
variable "github_infra_repo_id" { type = string }
variable "github_app_repo_id" { type = string }
variable "terraform_state_bucket" { type = string }

module "bootstrap" {
  source = "../../modules/bootstrap"

  project_id             = var.project_id
  github_org_id          = var.github_org_id
  github_infra_repo_id   = var.github_infra_repo_id
  terraform_state_bucket = var.terraform_state_bucket
}

module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id    = var.project_id
  location      = var.region
  repository_id = "applications"

  depends_on = [module.bootstrap]
}

module "app" {
  source = "../../modules/cloud-run-app"

  project_id                   = var.project_id
  region                       = var.region
  name                         = "app"
  runtime_account_id           = "app-runtime"
  deploy_account_id            = "app-deploy"
  wif_pool_name                = module.bootstrap.workload_identity_pool
  github_app_repo_id           = var.github_app_repo_id
  terraform_ci_service_account = module.bootstrap.terraform_service_account
  artifact_registry_location   = module.artifact_registry.location
  artifact_registry_repository = module.artifact_registry.repository_id

  depends_on = [module.bootstrap]
}
