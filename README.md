# gcp-platform

Shared **library** for Agentic Goose GCP projects: Terraform modules and GitHub Actions.

This repo is not a Terraform root. It has no remote state and is never applied to a project. Product infra repos (`ironzone-quickbooks-infra`, `oncall-install-infra`, a new project) call these modules and workflows.

## Layout

```
modules/
  bootstrap/           # WIF, terraform-ci SA, baseline APIs and CI IAM
  artifact-registry/   # Docker repo + cleanup policies
  cloud-run-app/       # runtime/deploy SAs, Cloud Run service, WIF for the app repo
  secrets/             # Secret Manager containers + per-secret IAM
  monitoring/          # HTTPS uptime, Cloud Run 5xx, email and billing alerts
.github/
  workflows/terraform.yml          # reusable plan/apply
  actions/docker-gar-build/        # Buildx + GAR push (no deploy)
  actions/firebase-hosting-deploy/ # Firebase CLI + WIF + Hosting publish (no build)
examples/
  caller-terraform.yml
  caller-deploy.yml          # containerised app on Cloud Run
  caller-deploy-static.yml   # site served directly by Firebase Hosting
  root/main.tf         # thin root showing how to stitch modules
```

SQL, Firebase, DNS, and bastions stay in the product repo until a second project needs them. Firebase *Hosting deployment* is the exception: it is an Actions concern rather than Terraform, and the two delivery shapes this account runs — a container on Cloud Run and a static site on Hosting — now have one action each, so a new front end does not start from a copied workflow.

Both deploy actions take the same `project_id` / `workload_identity_provider` / `service_account` inputs and both gate authentication on a boolean (`push` for the container, `deploy` for Hosting), so a pull request exercises the build and the config check without credentials. Neither action builds *and* deploys: the caller builds, the action publishes.

### Deploying a static site

```yaml
- uses: agentic-goose/gcp-platform/.github/actions/firebase-hosting-deploy@<full-commit-sha>
  with:
    config: firebase.json   # must already exist and name an existing hosting.public
    deploy: "true"
    project_id: ${{ vars.GCP_PROJECT_ID }}
    workload_identity_provider: ${{ vars.GCP_WIF_PROVIDER }}
    service_account: ${{ vars.GCP_DEPLOY_SERVICE_ACCOUNT }}
```

`project_id` is a resolved project id, not a `.firebaserc` alias, so the workflow log shows which project a run publishes to. Resolve the alias in the caller and check it against `GCP_PROJECT_ID` there — a project id that disagrees with its deploy target is the caller's bug to catch, and this action deliberately has no opinion about which targets exist. `firebase_tools_version` is pinned (default `15.28.1`); pass the version the repo tests against. The action deploys Hosting only — never Functions, Firestore or rules.

A caller whose release is gated on build provenance should keep that gate in its own step and call this action after it, or keep its own publish step; this action verifies that the config names a directory that exists, nothing about what is in it.

## First-time project (bootstrap chicken-and-egg)

1. Create the GCP project and a GCS state bucket by hand (or `gcloud`).
2. Copy `examples/root` into the new infra repo, set backend + tfvars.
3. `terraform apply` **locally** for bootstrap (WIF does not exist yet, so GitHub cannot apply this).
4. Set GitHub Actions variables from outputs (`GCP_WIF_PROVIDER`, `GCP_TERRAFORM_SERVICE_ACCOUNT`, `GCP_WIF_POOL`, …).
5. Point the infra workflow at `examples/caller-terraform.yml` and the app workflow at `examples/caller-deploy.yml`.
6. Pin workflow `uses:` and module sources to a full commit SHA available on `main`.

## Module source

```hcl
module "bootstrap" {
  source = "git::https://github.com/agentic-goose/gcp-platform.git//modules/bootstrap?ref=<full-commit-sha>"
  # ...
}
```

## Callers must grant Actions access

Reusable workflows and composite actions in this (private) repo require **Settings → Actions → Access** to allow other `agentic-goose` repositories (`user` on this account). Callers that clone Terraform modules from here also need secret `GCP_PLATFORM_READ_TOKEN`.

The reusable Terraform workflow accepts `github_environment` (empty = repo vars), `require_platform_token`, and `plan_marker`.

See [the monitoring module](modules/monitoring/README.md) for inputs, IAM prerequisites, tests, and existing-budget adoption.
