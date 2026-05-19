---
description: Rules for infrastructure-as-code, Kubernetes, Docker, CI/CD pipelines.
globs: ["**/*.tf", "**/*.tfvars", "terraform/**", "k8s/**", "kubernetes/**", "**/*.yaml", "**/*.yml", "Dockerfile*", "**/Dockerfile*", "docker-compose*.yml", "Chart.yaml", "templates/**", ".github/workflows/**", ".gitlab-ci.yml", ".circleci/config.yml"]
---

# Infrastructure code rules

## Required

- **Resources are named and tagged.** Every cloud resource has: project, environment, owner, cost-center tags. No anonymous `mybucket-1234`.
- **Least-privilege IAM.** Roles/policies grant the minimum needed. No `*:*` permissions in production.
- **State files are remote and locked.** Never commit local Terraform state. Use backend with locking (S3+DynamoDB, GCS, Terraform Cloud).
- **Plan before apply.** Every `terraform apply` has a `plan` reviewed first. CI runs `plan` on PRs.
- **Secrets are NOT in code or state files.** Use sealed-secrets, SOPS, AWS Secrets Manager, GCP Secret Manager, Vault. The actual value never appears in version control.

## Containers

- **Multi-stage Dockerfiles.** Builder stage with dev deps, final stage with only the runtime artifacts.
- **Pinned base images.** `node:20-alpine` is OK; `node:latest` is not. Better: SHA-pinned (`node:20-alpine@sha256:...`).
- **Non-root user in the final image.** Even if the image runs in a sandbox.
- **Reproducible builds.** `.dockerignore` excludes `.git`, `node_modules`, `.env*`, dev caches.
- **Small images.** No `apt-get install build-essential` in the final stage. No 2GB images for a 50MB binary.

## Kubernetes

- **Resource requests AND limits on every container.** Without requests, the scheduler can't place pods; without limits, one pod can starve the node.
- **Liveness + readiness probes.** A container without probes is invisible to k8s. Readiness gates traffic; liveness restarts on hang.
- **PodDisruptionBudgets for stateful or critical services.** Otherwise node drains can take everything down at once.
- **No `latest` image tags in manifests.** Pin to a semver tag or a digest.
- **`securityContext.runAsNonRoot: true`** unless impossible.

## CI/CD

- **Pipelines fail loud.** A flaky test that "usually works" gets quarantined, not retried until green.
- **No secrets in workflow logs.** Use the platform's secret masking.
- **Concurrent runs are safe.** Two deploys of the same branch shouldn't deadlock — gate with concurrency groups.
- **Rollback is a known procedure.** Document the command/button — don't discover it during an outage.

## Don't

- Don't manually edit cloud resources that IaC manages. Drift will burn you.
- Don't share long-lived cloud credentials. Use OIDC federation, IAM roles for service accounts, or short-lived tokens.
- Don't put cluster-admin or cloud-admin permissions in CI by default. Scope each job to what it needs.
- Don't `kubectl apply` to production from a laptop. CI does it, or a release process does it. Audit trail matters.
