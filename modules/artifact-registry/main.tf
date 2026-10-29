resource "google_artifact_registry_repository" "this" {
  project       = var.project_id
  location      = var.location
  repository_id = var.repository_id
  description   = var.description
  format        = "DOCKER"

  cleanup_policy_dry_run = false

  # Both policies are declined together: a KEEP with no DELETE prunes nothing,
  # and a DELETE with no KEEP has no floor under it.
  dynamic "cleanup_policies" {
    for_each = var.cleanup_policies == null ? [] : [var.cleanup_policies]

    content {
      id     = "keep-recent"
      action = "KEEP"

      most_recent_versions {
        keep_count = cleanup_policies.value.keep_count
      }
    }
  }

  dynamic "cleanup_policies" {
    for_each = var.cleanup_policies == null ? [] : [var.cleanup_policies]

    content {
      id     = "delete-old"
      action = "DELETE"

      condition {
        older_than = cleanup_policies.value.delete_older_than
      }
    }
  }
}
