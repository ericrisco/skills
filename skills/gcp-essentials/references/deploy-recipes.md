# Deploy recipes

Copy-paste runbooks. Replace `acme-prod`, region, image tag, and the billing account
id. Every block assumes `gcloud config set project acme-prod` and
`gcloud config set run/region europe-west1` are done.

## Build & push an image to Artifact Registry

```bash
gcloud artifacts repositories create app \
  --repository-format=docker --location=europe-west1
gcloud auth configure-docker europe-west1-docker.pkg.dev
docker build -t europe-west1-docker.pkg.dev/acme-prod/app/api:1.4.0 .
docker push europe-west1-docker.pkg.dev/acme-prod/app/api:1.4.0
```

## Deploy a private container with a dedicated SA

```bash
gcloud iam service-accounts create api-sa --display-name="api runtime"
gcloud run deploy api \
  --image=europe-west1-docker.pkg.dev/acme-prod/app/api:1.4.0 \
  --region=europe-west1 \
  --service-account=api-sa@acme-prod.iam.gserviceaccount.com \
  --no-allow-unauthenticated
```

## Attach Cloud SQL to the service

```bash
gcloud projects add-iam-policy-binding acme-prod \
  --member="serviceAccount:api-sa@acme-prod.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"
gcloud run services update api --region=europe-west1 \
  --add-cloudsql-instances=acme-prod:europe-west1:acme-db
# App connects via host=/cloudsql/acme-prod:europe-west1:acme-db
```

## Mount a Secret Manager secret

```bash
printf '%s' "$(openssl rand -base64 24)" | gcloud secrets create db-password --data-file=-
gcloud secrets add-iam-policy-binding db-password \
  --member="serviceAccount:api-sa@acme-prod.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
gcloud run services update api --region=europe-west1 \
  --set-secrets="DB_PASSWORD=db-password:latest"
```

To rotate: add a new version, then redeploy (or rely on `:latest`):

```bash
printf '%s' "$NEW" | gcloud secrets versions add db-password --data-file=-
```

## Budget alert

```bash
gcloud billing budgets create \
  --billing-account=0X0X0X-0X0X0X-0X0X0X \
  --display-name="acme-prod monthly" \
  --budget-amount=50 \
  --threshold-rule=percent=0.5 \
  --threshold-rule=percent=0.9 \
  --threshold-rule=percent=1.0
```

A budget alert notifies; it does **not** cap spend. To actually stop spend, wire the
Pub/Sub budget notification to a function that disables billing on the project.

## Full teardown (dependency order)

```bash
gcloud run services delete api --region=europe-west1 --quiet
gcloud sql instances delete acme-db --quiet
gcloud storage rm --recursive gs://acme-prod-uploads
gcloud secrets delete db-password --quiet
gcloud iam service-accounts delete api-sa@acme-prod.iam.gserviceaccount.com --quiet
# Optional: shut the whole project (30-day recoverable window)
gcloud projects delete acme-prod
```
