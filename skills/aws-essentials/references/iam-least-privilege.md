# IAM least-privilege — anatomy, workflow, and copy-ready templates

Depth offloaded from `SKILL.md`. Everything here keeps `Action` and `Resource` narrow and
prefers temporary credentials over long-lived keys.

## Policy JSON anatomy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadWriteOwnPrefix",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::acme-uploads/users/*",
      "Condition": { "Bool": { "aws:SecureTransport": "true" } }
    }
  ]
}
```

- `Version` is always the literal `2012-10-17` (a policy-language date, not "use the latest").
- `Sid` is an optional human label — use it; future-you reads policies more than writes them.
- An explicit `Deny` always wins over any `Allow`. Use `Deny` for guardrails, not for the
  everyday "what may this role do" — that should be a tight `Allow`.

## Condition keys worth knowing

| Key | Use | Example |
|---|---|---|
| `aws:SecureTransport` | force TLS | `"Bool": {"aws:SecureTransport": "true"}` |
| `aws:SourceArn` | confused-deputy guard on resource policies | restrict S3 bucket policy to one CloudFront distribution ARN |
| `aws:PrincipalTag/team` | attribute-based access (ABAC) | `"StringEquals": {"aws:PrincipalTag/team": "payments"}` |
| `s3:prefix` | limit which keys a `ListBucket` can see | `"StringLike": {"s3:prefix": ["users/${aws:userid}/*"]}` |

## The tighten-with-Access-Analyzer flow

Hand-authoring a minimal policy from scratch means guessing every API call a service makes —
you will be wrong and either over-grant or break it. Let CloudTrail tell you the truth.

```bash
# 1. Generate a fine-grained policy from what the role ACTUALLY called (CloudTrail-backed).
aws accessanalyzer start-policy-generation \
  --policy-generation-details '{"principalArn":"arn:aws:iam::123456789012:role/acme-task"}' \
  --cloud-trail-details '{ "trails":[{"cloudTrailArn":"arn:aws:cloudtrail:eu-west-1:123456789012:trail/acme","allRegions":true}], "accessRole":"arn:aws:iam::123456789012:role/AccessAnalyzerCT", "startTime":"2026-05-01T00:00:00Z" }'

aws accessanalyzer get-generated-policy --job-id <job-id>   # poll, then copy the JSON

# 2. Validate any policy against 100+ checks before you attach it.
aws accessanalyzer validate-policy \
  --policy-type IDENTITY_POLICY \
  --policy-document file://acme-task-policy.json
# Review findings: SECURITY_WARNING / ERROR / SUGGESTION. Fix before attaching.

# 3. Periodically prune: which permissions has nobody used?
aws iam generate-service-last-accessed-details --arn arn:aws:iam::123456789012:role/acme-task
```

Replace the broad managed policy you started with by the generated, validated one. Re-run the
last-accessed prune every quarter.

## ECS task: two roles, two policies

```json
// Trust policy — who may assume this role (same for task and execution role)
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "ecs-tasks.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
```

- **Execution role** permission policy: start from the AWS managed `AmazonECSTaskExecutionRolePolicy`
  (pull from ECR + write CloudWatch logs). Add `secretsmanager:GetSecretValue` *here* only for
  secrets injected by ECS at container start.
- **Task role** permission policy: your application's runtime grants — the scoped templates below.

## Copy-ready scoped templates

**S3 — read/write exactly one prefix:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Action": ["s3:GetObject","s3:PutObject","s3:DeleteObject"],
      "Resource": "arn:aws:s3:::acme-uploads/users/*" },
    { "Effect": "Allow", "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::acme-uploads",
      "Condition": { "StringLike": { "s3:prefix": ["users/*"] } } }
  ]
}
```

**Secrets Manager — read exactly one secret:**

```json
{
  "Version": "2012-10-17",
  "Statement": [{ "Effect": "Allow", "Action": "secretsmanager:GetSecretValue",
    "Resource": "arn:aws:secretsmanager:eu-west-1:123456789012:secret:acme/prod/db-*" }]
}
```

**CloudWatch Logs — write the app's own log group:**

```json
{
  "Version": "2012-10-17",
  "Statement": [{ "Effect": "Allow",
    "Action": ["logs:CreateLogStream","logs:PutLogEvents"],
    "Resource": "arn:aws:logs:eu-west-1:123456789012:log-group:/ecs/acme:*" }]
}
```

**Trust policy for human admin via federation** (Identity Center handles this for you; shown for
a self-managed assumable role):

```json
{
  "Version": "2012-10-17",
  "Statement": [{ "Effect": "Allow",
    "Principal": { "AWS": "arn:aws:iam::123456789012:root" },
    "Action": "sts:AssumeRole",
    "Condition": { "Bool": { "aws:MultiFactorAuthPresent": "true" } } }]
}
```

Note the MFA condition: an assumable role with no MFA requirement is barely better than a static
key. Require `aws:MultiFactorAuthPresent` on any human-assumed role.
