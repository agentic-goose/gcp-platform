resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = var.runtime_account_id
  display_name = "${var.name} runtime"
}

resource "google_service_account" "deploy" {
  project      = var.project_id
  account_id   = var.deploy_account_id
  display_name = "${var.name} GitHub deploy"
}

resource "google_artifact_registry_repository_iam_member" "deploy_writer" {
  project    = var.project_id
  location   = var.artifact_registry_location
  repository = var.artifact_registry_repository

  role   = "roles/artifactregistry.writer"
  member = "serviceAccount:${google_service_account.deploy.email}"
}

resource "google_service_account_iam_member" "deploy_runtime_user" {
  service_account_id = google_service_account.runtime.name

  role   = "roles/iam.serviceAccountUser"
  member = "serviceAccount:${google_service_account.deploy.email}"
}

resource "google_service_account_iam_member" "github_deploy" {
  service_account_id = google_service_account.deploy.name

  role = "roles/iam.workloadIdentityUser"

  member = "principalSet://iam.googleapis.com/${var.wif_pool_name}/attribute.repository_id/${var.github_app_repo_id}"
}

resource "google_service_account_iam_member" "terraform_ci_runtime_user" {
  service_account_id = google_service_account.runtime.name

  role   = "roles/iam.serviceAccountUser"
  member = "serviceAccount:${var.terraform_ci_service_account}"
}

resource "google_cloud_run_v2_service" "this" {
  project  = var.project_id
  name     = var.name
  location = var.region

  deletion_protection  = var.deletion_protection
  invoker_iam_disabled = var.invoker_iam_disabled

  template {
    service_account = google_service_account.runtime.email

    dynamic "vpc_access" {
      for_each = var.vpc_network != null && var.vpc_subnetwork != null ? [1] : []
      content {
        network_interfaces {
          network    = var.vpc_network
          subnetwork = var.vpc_subnetwork
        }
        egress = var.vpc_egress
      }
    }

    dynamic "volumes" {
      for_each = length(var.cloud_sql_instances) > 0 ? [1] : []
      content {
        name = "cloudsql"
        cloud_sql_instance {
          instances = var.cloud_sql_instances
        }
      }
    }

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      ports {
        container_port = var.container_port
      }

      dynamic "env" {
        for_each = var.env
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "volume_mounts" {
        for_each = length(var.cloud_sql_instances) > 0 ? [1] : []
        content {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }
    }

    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }
  }

  depends_on = [google_service_account_iam_member.terraform_ci_runtime_user]

  lifecycle {
    ignore_changes = [
      client,
      client_version,
      template[0].containers[0].image,
      template[0].containers[0].env,
      template[0].scaling,
    ]
  }
}

resource "google_cloud_run_v2_service_iam_member" "deploy_developer" {
  project  = var.project_id
  location = google_cloud_run_v2_service.this.location
  name     = google_cloud_run_v2_service.this.name

  role   = "roles/run.developer"
  member = "serviceAccount:${google_service_account.deploy.email}"
}
