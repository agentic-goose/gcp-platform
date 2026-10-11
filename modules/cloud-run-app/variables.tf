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
  # Required on purpose, with no default in either direction.
  #
  # It used to default to true, so every caller that said nothing published its
  # service to the internet — which is how both services on the first project
  # ended up publicly invokable without anyone choosing it. Flipping the
  # default to false would have fixed that case and created a worse one: a
  # caller pinning an older commit inherits the old default until it bumps its
  # ref, and the bump would then silently take a working public service
  # private. In this stack that would break GoHighLevel webhook delivery, whose
  # sender cannot present a Google OIDC token, and a Firebase Hosting rewrite,
  # which has no service agent that can be granted roles/run.invoker.
  #
  # So neither default is safe: one publishes by omission, the other revokes by
  # omission. With no default, Terraform refuses to plan until the caller says
  # which it wants, and a pin bump fails loudly at plan time rather than
  # changing who can reach the service. Exposure is a decision, so it is stated
  # at the call site, next to the reason.
  description = "If true, the service is publicly invokable (no IAM on invoke). Set false and name invokers unless the service must answer requests from senders that cannot authenticate to Google."
  type        = bool
}

variable "invokers" {
  # What makes a private service usable. Without this the module could only
  # produce a service nothing was allowed to call, so the only way to make one
  # reachable was invoker_iam_disabled = true — a default of false would have
  # pushed every caller straight back to public. Eventarc, Cloud Scheduler and
  # a calling service each need naming here instead.
  description = "Members granted roles/run.invoker, e.g. [\"serviceAccount:eventarc@project.iam.gserviceaccount.com\"]. A private service is unreachable until something is listed here or granted the role elsewhere."
  type        = list(string)
  default     = []

  validation {
    # roles/run.invoker takes a principal, and an IAM binding with a bare
    # email is accepted by Terraform and rejected by the API at apply time,
    # which is a slow way to find a typo.
    condition = alltrue([
      for member in var.invokers :
      can(regex("^(serviceAccount|user|group|domain|principal|principalSet|allUsers|allAuthenticatedUsers):", member)) ||
      contains(["allUsers", "allAuthenticatedUsers"], member)
    ])
    error_message = "Each invoker must be a fully qualified IAM member, such as serviceAccount:name@project.iam.gserviceaccount.com."
  }
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
