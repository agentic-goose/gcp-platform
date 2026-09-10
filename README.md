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
.github/
  workflows/terraform.yml          # reusable plan/apply
  actions/docker-gar-build/        # Buildx + GAR push (no deploy)
examples/
  caller-terraform.yml
  caller-deploy.yml
  root/main.tf         # thin root showing how to stitch modules
```

SQL, Firebase, DNS, and bastions stay in the product repo until a second project needs them.

## First-time project (bootstrap chicken-and-egg)

1. Create the GCP project and a GCS state bucket by hand (or `gcloud`).
2. Copy `examples/root` into the new infra repo, set backend + tfvars.
3. `terraform apply` **locally** for bootstrap (WIF does not exist yet, so GitHub cannot apply this).
4. Set GitHub Actions variables from outputs (`GCP_WIF_PROVIDER`, `GCP_TERRAFORM_SERVICE_ACCOUNT`, `GCP_WIF_POOL`, …).
5. Point the infra workflow at `examples/caller-terraform.yml` and the app workflow at `examples/caller-deploy.yml`.
6. Pin `uses:` to a tag (e.g. `@v1`) once this path is proven; `@main` is fine while iterating.

## Module source

```hcl
module "bootstrap" {
  source = "git::https://github.com/agentic-goose/gcp-platform.git//modules/bootstrap?ref=main"
  # ...
}
```

## Callers must grant Actions access

Reusable workflows and composite actions in this (private) repo require each caller repo to be allowed under **Settings → Actions → Access**.
