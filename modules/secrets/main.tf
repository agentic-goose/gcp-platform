resource "google_secret_manager_secret" "this" {
  for_each = var.secret_ids

  project   = var.project_id
  secret_id = each.value

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "managed" {
  for_each = toset(nonsensitive(keys(var.managed_secret_data)))

  secret      = google_secret_manager_secret.this[each.key].id
  secret_data = var.managed_secret_data[each.key]
}

resource "google_secret_manager_secret_iam_member" "runtime_accessor" {
  for_each = var.secret_ids

  project   = var.project_id
  secret_id = google_secret_manager_secret.this[each.value].secret_id

  role   = "roles/secretmanager.secretAccessor"
  member = var.runtime_member
}

resource "google_secret_manager_secret_iam_member" "developers_version_manager" {
  for_each = {
    for pair in setproduct(var.developer_members, var.secret_ids) :
    "${pair[0]}/${pair[1]}" => { member = pair[0], secret_id = pair[1] }
  }

  project   = var.project_id
  secret_id = google_secret_manager_secret.this[each.value.secret_id].secret_id

  role   = "roles/secretmanager.secretVersionManager"
  member = each.value.member
}
