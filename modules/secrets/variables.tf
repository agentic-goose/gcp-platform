variable "project_id" {
  type = string
}

variable "secret_ids" {
  description = "Secret Manager secret IDs to create (containers only unless managed_secret_data provides a value)"
  type        = set(string)
}

variable "runtime_member" {
  description = "IAM member granted secretAccessor on every secret (usually the runtime SA)"
  type        = string
}

variable "developer_members" {
  description = "IAM members granted secretVersionManager on every secret"
  type        = list(string)
  default     = []
}

variable "managed_secret_data" {
  description = "secret_id => value for secrets Terraform should version. Others are populated out of band."
  type        = map(string)
  default     = {}
  sensitive   = true
}
