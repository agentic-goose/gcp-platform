locals {
  uptime_checks          = { for check in var.uptime_checks : check.name => check }
  billing_budget_enabled = trimspace(var.billing_account_id) != ""
}

resource "google_project_service" "monitoring" {
  project            = var.project_id
  service            = "monitoring.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "billingbudgets" {
  count = local.billing_budget_enabled ? 1 : 0

  project            = var.project_id
  service            = "billingbudgets.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_iam_member" "terraform_ci_monitoring_admin" {
  count = var.terraform_ci_service_account == null ? 0 : 1

  project = var.project_id
  role    = "roles/monitoring.admin"
  member  = "serviceAccount:${var.terraform_ci_service_account}"
}

resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "Email alerts"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }

  depends_on = [
    google_project_service.monitoring,
    google_project_iam_member.terraform_ci_monitoring_admin,
  ]
}

resource "google_monitoring_uptime_check_config" "https" {
  for_each = local.uptime_checks

  project      = var.project_id
  display_name = each.value.name
  timeout      = var.uptime_timeout
  period       = var.uptime_period

  http_check {
    path         = each.value.path
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = each.value.host
    }
  }

  selected_regions = var.uptime_regions

  depends_on = [
    google_project_service.monitoring,
    google_project_iam_member.terraform_ci_monitoring_admin,
  ]
}

resource "google_monitoring_alert_policy" "uptime" {
  count = length(local.uptime_checks) > 0 ? 1 : 0

  project      = var.project_id
  display_name = "Uptime check failed"
  combiner     = "OR"
  enabled      = true

  dynamic "conditions" {
    for_each = local.uptime_checks
    content {
      display_name = "Uptime failed: ${conditions.value.name}"

      condition_threshold {
        filter = join(" AND ", [
          "resource.type = \"uptime_url\"",
          "metric.type = \"monitoring.googleapis.com/uptime_check/check_passed\"",
          "metric.labels.check_id = \"${google_monitoring_uptime_check_config.https[conditions.key].uptime_check_id}\"",
        ])

        aggregations {
          alignment_period     = "1200s"
          per_series_aligner   = "ALIGN_NEXT_OLDER"
          cross_series_reducer = "REDUCE_COUNT_FALSE"
          group_by_fields      = ["resource.label.host"]
        }

        comparison      = "COMPARISON_GT"
        threshold_value = 1
        duration        = "60s"

        trigger {
          count = 1
        }
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "604800s"
  }

  depends_on = [google_project_iam_member.terraform_ci_monitoring_admin]
}

resource "google_monitoring_alert_policy" "cloud_run_5xx" {
  count = length(var.cloud_run_5xx_services) > 0 ? 1 : 0

  project      = var.project_id
  display_name = "Cloud Run 5xx"
  combiner     = "OR"
  enabled      = true

  dynamic "conditions" {
    for_each = toset(var.cloud_run_5xx_services)
    content {
      display_name = "5xx: ${conditions.value}"

      condition_threshold {
        filter = join(" AND ", [
          "resource.type = \"cloud_run_revision\"",
          "resource.labels.service_name = \"${conditions.value}\"",
          "metric.type = \"run.googleapis.com/request_count\"",
          "metric.labels.response_code_class = \"5xx\"",
        ])

        aggregations {
          alignment_period     = "300s"
          per_series_aligner   = "ALIGN_SUM"
          cross_series_reducer = "REDUCE_SUM"
          group_by_fields      = ["resource.label.service_name"]
        }

        comparison      = "COMPARISON_GT"
        threshold_value = 5
        duration        = "0s"

        trigger {
          count = 1
        }
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "604800s"
  }

  depends_on = [google_project_iam_member.terraform_ci_monitoring_admin]
}

data "google_project" "budget" {
  count      = local.billing_budget_enabled ? 1 : 0
  project_id = var.project_id
}

resource "google_billing_budget" "monthly" {
  count = local.billing_budget_enabled ? 1 : 0

  billing_account = var.billing_account_id
  display_name    = var.budget_display_name

  budget_filter {
    projects        = ["projects/${data.google_project.budget[0].number}"]
    calendar_period = "MONTH"
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.budget_amount)
    }
  }

  dynamic "threshold_rules" {
    for_each = var.budget_threshold_percents
    content {
      threshold_percent = threshold_rules.value
    }
  }

  all_updates_rule {
    monitoring_notification_channels = [
      google_monitoring_notification_channel.email.id,
    ]
    disable_default_iam_recipients = true
  }

  depends_on = [google_project_service.billingbudgets]
}
