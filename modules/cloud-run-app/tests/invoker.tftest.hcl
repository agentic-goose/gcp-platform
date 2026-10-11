# Who is allowed to call a service this module creates.
#
# Nothing covered this before, and the module's default published every
# service that did not say otherwise. The first project on this platform ended
# up with two publicly invokable services without anyone choosing it, which is
# the outcome these assertions exist to make impossible to reintroduce
# silently.

# That invoker_iam_disabled is *required* is deliberately not asserted here.
# expect_failures covers validation blocks and pre/postconditions; a missing
# required variable is a configuration error, which fails the run rather than
# reporting a checkable object. It is verified by running a plan with the
# variable absent and reading the error — see the pull request.

mock_provider "google" {}

variables {
  project_id                   = "test-cloud-run"
  region                       = "us-central1"
  name                         = "example-service"
  runtime_account_id           = "example-runtime"
  deploy_account_id            = "example-deploy"
  wif_pool_name                = "projects/123/locations/global/workloadIdentityPools/github-actions"
  github_app_repo_id           = "1234567"
  terraform_ci_service_account = "terraform-ci@test-cloud-run.iam.gserviceaccount.com"
  artifact_registry_location   = "us-central1"
  artifact_registry_repository = "applications"
  # Stated here because the module requires it. A run that wants the other
  # value overrides it in its own variables block, which is the whole point:
  # neither value is reachable by omission.
  invoker_iam_disabled = false
}

run "private_when_the_caller_says_so" {
  command = plan

  assert {
    condition     = google_cloud_run_v2_service.this.invoker_iam_disabled == false
    error_message = "A caller that asks for a private service must get one."
  }

  assert {
    condition     = length(google_cloud_run_v2_service_iam_member.invokers) == 0
    error_message = "No invoker should be granted unless one was named."
  }
}

run "named_invokers_get_the_role" {
  command = plan

  variables {
    invokers = [
      "serviceAccount:eventarc@test-cloud-run.iam.gserviceaccount.com",
      "serviceAccount:scheduler@test-cloud-run.iam.gserviceaccount.com",
    ]
  }

  assert {
    condition     = length(google_cloud_run_v2_service_iam_member.invokers) == 2
    error_message = "Each named invoker needs its own binding."
  }

  assert {
    condition = alltrue([
      for member in google_cloud_run_v2_service_iam_member.invokers :
      member.role == "roles/run.invoker"
    ])
    error_message = "Invokers must be granted roles/run.invoker and nothing else."
  }

  # A private service with named invokers is the combination the module exists
  # to make possible; asserting it together is what proves the default is
  # usable rather than merely safe.
  assert {
    condition     = google_cloud_run_v2_service.this.invoker_iam_disabled == false
    error_message = "Naming invokers must not make the service public."
  }
}

run "public_is_opt_in_and_explicit" {
  command = plan

  variables {
    invoker_iam_disabled = true
  }

  assert {
    condition     = google_cloud_run_v2_service.this.invoker_iam_disabled == true
    error_message = "A caller that asks for a public service must get one."
  }
}

run "an_invoker_without_a_principal_type_is_refused" {
  command = plan

  variables {
    # An IAM binding with a bare email is accepted by Terraform and rejected by
    # the API at apply time, which is a slow and confusing way to find a typo.
    invokers = ["eventarc@test-cloud-run.iam.gserviceaccount.com"]
  }

  expect_failures = [var.invokers]
}
