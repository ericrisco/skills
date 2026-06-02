# IAM & auth

Depth for the IAM section of SKILL.md. Predefined roles, keyless CI, impersonation,
drift detection.

## Predefined roles for a typical product

Prefer these Google-maintained roles over primitives or custom roles. Bind them to the
service's dedicated SA at the narrowest resource scope the role supports.

| Need | Role | Scope it to |
|------|------|-------------|
| Connect to Cloud SQL from the workload | `roles/cloudsql.client` | project |
| Read/write objects in one bucket | `roles/storage.objectAdmin` | the bucket |
| Read object content only | `roles/storage.objectViewer` | the bucket |
| Read one secret's value | `roles/secretmanager.secretAccessor` | the secret |
| Invoke a private Cloud Run service | `roles/run.invoker` | the service |
| Push/pull container images | `roles/artifactregistry.writer` | the repo |
| Write logs/metrics from the app | usually implicit on Cloud Run runtime SA | — |

Bind at resource scope when possible — e.g. a secret, not the project:

```bash
gcloud secrets add-iam-policy-binding db-password \
  --member="serviceAccount:api-sa@acme-prod.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

## Workload Identity Federation for GitHub Actions (keyless)

No JSON key downloaded, ever. GitHub's OIDC token is exchanged for short-lived GCP
credentials.

```bash
# 1. A pool + an OIDC provider that trusts GitHub's issuer
gcloud iam workload-identity-pools create github \
  --location=global --display-name="GitHub Actions"

gcloud iam workload-identity-pools providers create-oidc github-oidc \
  --location=global --workload-identity-pool=github \
  --display-name="GitHub OIDC" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository=='acme/api'"

# 2. Let the deploy SA be impersonated only from that repo
PROJECT_NUM=$(gcloud projects describe acme-prod --format='value(projectNumber)')
gcloud iam service-accounts add-iam-policy-binding \
  deployer@acme-prod.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUM}/locations/global/workloadIdentityPools/github/attribute.repository/acme/api"
```

In the workflow, use `google-github-actions/auth` with the provider resource name and
`service_account` — never a `credentials_json` secret. The `attribute-condition`
pinning the exact repo is the security boundary; without it any repo could mint
credentials.

## Service account impersonation

Run a one-off command *as* a service account without holding its key. The caller needs
`roles/iam.serviceAccountTokenCreator` on the target SA.

```bash
gcloud storage ls gs://acme-prod-uploads \
  --impersonate-service-account=api-sa@acme-prod.iam.gserviceaccount.com
```

Use this to test that an SA actually has the access you think it does — least surprise
before deploy.

## IAM Recommender (catch drift)

The Recommender flags roles a member has not used in 90 days, so you can prune
over-grants. Review it on a schedule.

```bash
gcloud recommender recommendations list \
  --project=acme-prod --location=global \
  --recommender=google.iam.policy.Recommender \
  --format="table(content.overview)"
```

## IAM Conditions

Attach a condition to narrow a binding by time or resource attribute — e.g. access to
objects under one prefix only.

```bash
gcloud projects add-iam-policy-binding acme-prod \
  --member="serviceAccount:api-sa@acme-prod.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer" \
  --condition='expression=resource.name.startsWith("projects/_/buckets/acme-prod-uploads/objects/public/"),title=public-prefix-only'
```
