variable "project_id" {
  description = "GCP project to monitor"
  type        = string
}

variable "alert_email" {
  description = "Email for uptime, 5xx, and budget notifications. Verify delivery after applying."
  type        = string
}

variable "uptime_checks" {
  description = "HTTPS uptime probes. Each unique name becomes its own check."
  type = list(object({
    name = string
    host = string
    path = string
  }))
  default = []

  validation {
    condition     = length(var.uptime_checks) == length(distinct([for check in var.uptime_checks : check.name]))
    error_message = "Uptime check names must be unique."
  }

  validation {
    condition = alltrue([for check in var.uptime_checks :
      trimspace(check.name) != "" && can(regex("^[A-Za-z0-9.-]+$", check.host)) && startswith(check.path, "/")
    ])
    error_message = "Each uptime check needs a name, a hostname without a scheme or path, and an absolute path."
  }
}

variable "cloud_run_5xx_services" {
  description = "Cloud Run service names to alert when 5xx responses appear"
  type        = list(string)
  default     = []
}

variable "uptime_period" {
  description = "Probe interval. Allowed values include 60s, 300s, 600s, 900s."
  type        = string
  default     = "300s"

  validation {
    condition     = contains(["60s", "300s", "600s", "900s"], var.uptime_period)
    error_message = "uptime_period must be 60s, 300s, 600s, or 900s."
  }
}

variable "uptime_timeout" {
  type    = string
  default = "10s"
}

variable "uptime_regions" {
  description = "Checker regions. USA-only keeps probe volume low for a small site."
  type        = list(string)
  default     = ["USA"]
}

variable "billing_account_id" {
  description = "Billing account ID (XXXXXX-XXXXXX-XXXXXX). Empty skips the budget resource."
  type        = string
  default     = ""
}

variable "budget_amount" {
  description = "Monthly budget in USD. Threshold percents are relative to this amount."
  type        = number
  default     = 25

  validation {
    condition     = var.budget_amount > 0 && floor(var.budget_amount) == var.budget_amount
    error_message = "budget_amount must be a positive whole number of USD."
  }
}

variable "budget_threshold_percents" {
  description = "Alert at these fractions of budget_amount. Fractions must be positive and unique."
  type        = list(number)
  default     = [0.10, 0.15, 0.25, 0.50, 1.0]

  validation {
    condition = length(var.budget_threshold_percents) > 0 && alltrue([
      for threshold in var.budget_threshold_percents : threshold > 0
    ]) && length(distinct(var.budget_threshold_percents)) == length(var.budget_threshold_percents)
    error_message = "Budget thresholds must be a nonempty list of unique positive fractions."
  }
}

variable "budget_display_name" {
  type    = string
  default = "Monthly spend"
}

variable "terraform_ci_service_account" {
  description = "If set, grant this SA monitoring.admin so it can manage this module."
  type        = string
  default     = null
}

variable "budget_scope" {
  description = "PROJECT filters to this project; BILLING_ACCOUNT preserves an account-wide budget when importing one."
  type        = string
  default     = "PROJECT"

  validation {
    condition     = contains(["PROJECT", "BILLING_ACCOUNT"], var.budget_scope)
    error_message = "budget_scope must be PROJECT or BILLING_ACCOUNT."
  }
}
