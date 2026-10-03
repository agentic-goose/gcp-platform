output "notification_channel_id" {
  value = google_monitoring_notification_channel.email.id
}

output "uptime_check_ids" {
  value = {
    for name, check in google_monitoring_uptime_check_config.https :
    name => check.uptime_check_id
  }
}

output "budget_name" {
  value = try(google_billing_budget.monthly[0].name, null)
}
