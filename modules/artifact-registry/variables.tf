variable "project_id" {
  type = string
}

variable "location" {
  type = string
}

variable "repository_id" {
  type = string
}

variable "description" {
  type    = string
  default = "Docker images"
}

# Image retention, and required on purpose, with no default in either
# direction.
#
# This module used to create a KEEP and a DELETE policy unconditionally, with
# `cleanup_policy_dry_run = false`, and no way to decline them. Any caller that
# said nothing got live deletion of images older than thirty days.
#
# That is destructive by omission, and it was caught while porting a production
# environment onto this module: its registry carried no cleanup policies, both
# of its services had last deployed thirty-one days earlier, and adopting the
# module would have deleted the exact images production was running. The
# services keep serving — the image is already pulled — but rollback, the thing
# you want precisely when a deploy goes wrong, is gone.
#
# Defaulting the other way is not safe either: a caller relying on the old
# behaviour loses its cleanup silently at its next pin bump, and a registry
# grows without bound. So neither default is safe — one deletes by omission,
# the other accumulates by omission — and the caller has to say which it wants.
# Same reasoning as `invoker_iam_disabled` in cloud-run-app; CI enforces both.
#
# `null` means no cleanup policies at all, which is a legitimate answer and the
# one a registry holding images you may need to roll back to should give.
variable "cleanup_policies" {
  description = "Image retention, or null for none. keep_count is how many recent versions to keep; delete_older_than is a duration string, e.g. 2592000s for 30 days."
  type = object({
    keep_count        = number
    delete_older_than = string
  })
  nullable = true

  validation {
    condition     = var.cleanup_policies == null ? true : var.cleanup_policies.keep_count > 0
    error_message = "keep_count must be greater than zero; a KEEP policy of zero keeps nothing."
  }

  validation {
    condition     = var.cleanup_policies == null ? true : can(regex("^[0-9]+s$", var.cleanup_policies.delete_older_than))
    error_message = "delete_older_than must be a duration in seconds, e.g. \"2592000s\" for 30 days."
  }
}
