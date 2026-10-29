# Whether this repository deletes images, and whether a caller can decline.
#
# Nothing covered this before. The module created a KEEP and a DELETE policy
# unconditionally with dry-run off, so a caller that said nothing got live
# deletion of anything older than thirty days. That was found while porting a
# production environment onto this module: its registry had no cleanup
# policies, both of its services had last deployed thirty-one days earlier, and
# adopting the module would have deleted the images production was running,
# taking rollback with them.
#
# That `cleanup_policies` is *required* is deliberately not asserted here.
# expect_failures covers validation blocks and pre/postconditions; a missing
# required variable is a configuration error, which fails the run rather than
# reporting a checkable object. CI checks it by reading variables.tf instead —
# the same treatment invoker_iam_disabled gets in cloud-run-app.

mock_provider "google" {}

variables {
  project_id    = "test-artifact-registry"
  location      = "us-central1"
  repository_id = "applications"
  cleanup_policies = {
    keep_count        = 10
    delete_older_than = "2592000s"
  }
}

run "policies_are_created_when_asked_for" {
  command = plan

  assert {
    condition     = length(google_artifact_registry_repository.this.cleanup_policies) == 2
    error_message = "A caller asking for cleanup must get both the KEEP and the DELETE policy."
  }

  assert {
    condition = length([
      for p in google_artifact_registry_repository.this.cleanup_policies :
      p if p.action == "DELETE"
    ]) == 1
    error_message = "The DELETE policy is what prunes; without it KEEP removes nothing."
  }
}

run "null_declines_cleanup_entirely" {
  command = plan

  variables {
    cleanup_policies = null
  }

  # The case the production port needs: adopt this module without the registry
  # gaining a policy that deletes images still needed for a rollback.
  assert {
    condition     = length(google_artifact_registry_repository.this.cleanup_policies) == 0
    error_message = "cleanup_policies = null must create no policies at all, so adopting this module cannot start deleting images."
  }
}

run "keep_count_of_zero_is_refused" {
  command = plan

  variables {
    cleanup_policies = {
      keep_count        = 0
      delete_older_than = "2592000s"
    }
  }

  expect_failures = [var.cleanup_policies]
}

run "a_duration_without_seconds_is_refused" {
  command = plan

  variables {
    cleanup_policies = {
      keep_count        = 10
      delete_older_than = "30d"
    }
  }

  # The API takes seconds. "30d" is accepted by Terraform and rejected at apply.
  expect_failures = [var.cleanup_policies]
}
