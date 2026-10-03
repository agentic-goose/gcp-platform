# Monitoring

Creates an email notification channel, HTTPS uptime checks with certificate
validation, an uptime failure policy, and a Cloud Run 5xx policy. A nonempty
`billing_account_id` also enables a project-scoped monthly USD budget. Empty
probe/service lists omit their respective policies; an empty billing account
omits both the budget and its API/data lookup.

Use a full commit SHA in the module source. Root modules own provider locks.

```hcl
module "monitoring" {
  source = "git::https://github.com/agentic-goose/gcp-platform.git//modules/monitoring?ref=<full-commit-sha>"

  project_id         = var.project_id
  alert_email        = "alerts@example.com"
  billing_account_id = var.billing_account_id
  budget_amount      = 25
  budget_threshold_percents = [0.10, 0.15, 0.25, 0.50, 1.0]

  uptime_checks = [
    { name = "website", host = "www.example.com", path = "/" },
  ]
  cloud_run_5xx_services = ["app"]
}
```

Checks default to every five minutes from USA locations. The uptime policy
requires more than one failing checker for 60 seconds, using the most recent
sample in a 20-minute alignment period. Each Cloud Run condition alerts on more
than five 5xx responses summed across revisions in a five-minute window. All
policies use the email channel. Verify notification delivery after applying.

The budget defaults to $25 with 10/15/25/50/100% thresholds ($2.50, $3.75,
$6.25, $12.50, $25). Set the amount and fractions explicitly when adopting an
existing budget. The budget uses the numeric project identifier resolved by
`google_project`; budget API filters cannot use the textual project ID.
Set `budget_scope = "BILLING_ACCOUNT"` when adopting an account-wide budget;
the default `PROJECT` scope limits spending to the specified project.
Budget notifications add the email channel and retain default billing IAM recipients. A budget sends alerts; it does not cap spending.

## Permissions and existing resources

The applying identity needs permission to enable APIs and manage Monitoring
resources. If `terraform_ci_service_account` is supplied, the module grants it
`roles/monitoring.admin`; creating that grant still requires project IAM admin
access. Billing permissions are separate: grant the applying identity
`roles/billing.costsManager` on the billing account before planning a budget.
The module does not grant billing-account IAM. Reading project metadata also
requires `resourcemanager.projects.get`.

When using user ADCs for a budget, configure the root Google provider with
`billing_project` and `user_project_override = true` and ensure the identity has
`serviceusage.services.use` on that quota project.

Import an existing budget instead of creating a duplicate. Inspect its project
scope, currency, thresholds and notification recipients before adopting it:

```hcl
import {
  to = module.monitoring.google_billing_budget.monthly[0]
  id = "billingAccounts/ACCOUNT_ID/budgets/BUDGET_ID"
}
```

Review the plan for an import/update, rather than a second budget. Import any
existing Monitoring resources at the corresponding module addresses as well.

## Validation

Terraform 1.7+ is needed for mocked tests (module usage supports 1.6+):

```sh
terraform init -backend=false
terraform validate
terraform test
```

Tests use a mocked provider and do not access GCP or create resources.
