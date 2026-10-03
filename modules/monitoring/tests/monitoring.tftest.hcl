mock_provider "google" {
  mock_data "google_project" {
    defaults = {
      number = "123456789012"
    }
  }
}

variables {
  project_id  = "test-monitoring"
  alert_email = "alerts@example.com"
}

run "no_optional_resources" {
  command = plan

  assert {
    condition = (
      length(google_monitoring_uptime_check_config.https) == 0 &&
      length(google_monitoring_alert_policy.uptime) == 0 &&
      length(google_monitoring_alert_policy.cloud_run_5xx) == 0 &&
      length(google_billing_budget.monthly) == 0 &&
      length(google_project_service.billingbudgets) == 0 &&
      length(data.google_project.budget) == 0
    )
    error_message = "Optional probes, alerts, and billing resources must be absent when not configured."
  }
}

run "configured_monitoring" {
  command = plan

  variables {
    billing_account_id           = "000000-000000-000000"
    terraform_ci_service_account = "terraform-ci@test-monitoring.iam.gserviceaccount.com"
    uptime_checks = [
      { name = "website", host = "www.example.com", path = "/" },
      { name = "sync", host = "sync.example.com", path = "/healthz" },
    ]
    cloud_run_5xx_services = ["website", "sync"]
  }

  assert {
    condition     = google_billing_budget.monthly[0].budget_filter[0].projects == toset(["projects/123456789012"])
    error_message = "The budget must filter by project number, not project ID."
  }

  assert {
    condition = (
      google_billing_budget.monthly[0].amount[0].specified_amount[0].units == "25" &&
      google_billing_budget.monthly[0].budget_filter[0].calendar_period == "MONTH" &&
      toset([for rule in google_billing_budget.monthly[0].threshold_rules : rule.threshold_percent]) == toset([0.1, 0.15, 0.25, 0.5, 1])
    )
    error_message = "The default monthly budget must be $25 with the configured alert thresholds."
  }

  assert {
    condition = alltrue([for check in google_monitoring_uptime_check_config.https :
      check.http_check[0].use_ssl && check.http_check[0].validate_ssl && check.http_check[0].port == 443
    ])
    error_message = "Every probe must verify HTTPS certificates."
  }

  assert {
    condition = (
      length(google_monitoring_alert_policy.uptime[0].conditions) == 2 &&
      length(google_monitoring_alert_policy.cloud_run_5xx[0].conditions) == 2 &&
      google_monitoring_notification_channel.email.labels.email_address == "alerts@example.com"
    )
    error_message = "Both probes and services must have alert conditions and an email destination."
  }
}

run "reject_fractional_dollars" {
  command = plan
  variables {
    budget_amount = 25.5
  }
  expect_failures = [var.budget_amount]
}

run "reject_empty_thresholds" {
  command = plan
  variables {
    budget_threshold_percents = []
  }
  expect_failures = [var.budget_threshold_percents]
}

run "reject_negative_threshold" {
  command = plan
  variables {
    budget_threshold_percents = [-0.1]
  }
  expect_failures = [var.budget_threshold_percents]
}

run "reject_duplicate_check_names" {
  command = plan
  variables {
    uptime_checks = [
      { name = "website", host = "www.example.com", path = "/" },
      { name = "website", host = "example.com", path = "/" },
    ]
  }
  expect_failures = [var.uptime_checks]
}

run "adopt_account_budget" {
  command = plan
  variables {
    billing_account_id        = "000000-000000-000000"
    budget_scope              = "BILLING_ACCOUNT"
    budget_amount             = 25
    budget_threshold_percents = [0.5, 0.9, 1.0, 1.5]
  }
  assert {
    condition = (
      google_billing_budget.monthly[0].budget_filter[0].projects == null &&
      length(data.google_project.budget) == 0 &&
      !google_billing_budget.monthly[0].all_updates_rule[0].disable_default_iam_recipients &&
      toset([for rule in google_billing_budget.monthly[0].threshold_rules : rule.threshold_percent]) == toset([0.5, 0.9, 1.0, 1.5])
    )
    error_message = "Adopting an account-wide budget must preserve account scope, IAM recipients and chosen thresholds."
  }
}
