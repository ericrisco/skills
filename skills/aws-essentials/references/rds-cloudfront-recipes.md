# RDS and CloudFront — end-to-end recipes

Depth offloaded from `SKILL.md`. Two complete paths: an encrypted Multi-AZ Postgres wired to an
app, and a public CloudFront distribution over a private S3 origin via OAC.

## RDS — encrypted Multi-AZ Postgres, wired to ECS

### 1. Security groups — the DB SG references the app SG, never `0.0.0.0/0`

```bash
# App tasks' SG already exists: sg-app. Create the DB SG and allow ONLY the app SG on 5432.
aws ec2 create-security-group --group-name acme-db --description "RDS ingress from app only" \
  --vpc-id vpc-0abc --query GroupId --output text   # -> sg-app-db

aws ec2 authorize-security-group-ingress \
  --group-id sg-app-db \
  --protocol tcp --port 5432 \
  --source-group sg-app          # source is the SG, not a CIDR — never 0.0.0.0/0
```

### 2. Create the instance — encrypted at create time, Multi-AZ, not public

```bash
aws rds create-db-instance \
  --db-instance-identifier acme-prod \
  --engine postgres --engine-version 16 \
  --db-instance-class db.t4g.small \
  --allocated-storage 20 --storage-type gp3 \
  --storage-encrypted --kms-key-id alias/acme-rds \
  --multi-az \
  --no-publicly-accessible \
  --vpc-security-group-ids sg-app-db \
  --db-subnet-group-name acme-private \
  --master-username acme \
  --manage-master-user-password \
  --backup-retention-period 7
```

- `--storage-encrypted` **must** be set now. You cannot encrypt an existing instance in place;
  the fix is snapshot → `copy-db-snapshot` with `--kms-key-id` → `restore-db-instance-from-db-snapshot`.
  Multi-AZ *clusters* can't even do that directly. Encryption covers storage, backups, replicas,
  and snapshots.
- `--kms-key-id alias/acme-rds` uses a customer-managed key dedicated to RDS (preferred over the
  AWS-managed default).
- `--manage-master-user-password` puts the master password in Secrets Manager — no plaintext.

### 3. Secrets Manager — rotation + app retrieval

```bash
# Find the managed secret ARN RDS created:
aws rds describe-db-instances --db-instance-identifier acme-prod \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' --output text

# Turn on automatic rotation (RDS provides the rotation Lambda for managed secrets):
aws secretsmanager rotate-secret --secret-id <arn> \
  --rotation-rules '{"AutomaticallyAfterDays": 30}'
```

The ECS **task role** gets `secretsmanager:GetSecretValue` on that exact secret ARN (template in
`iam-least-privilege.md`). The app reads the secret at startup — never bake the password into a
task-definition env var (it leaks via task-definition history and logs). Connect over TLS.

## CloudFront + OAC over a private S3 origin

### 1. Create the Origin Access Control

```bash
aws cloudfront create-origin-access-control --origin-access-control-config '{
  "Name": "acme-site-oac",
  "OriginAccessControlOriginType": "s3",
  "SigningBehavior": "always",
  "SigningProtocol": "sigv4"
}'   # -> note the OAC Id
```

`"SigningBehavior": "always"` is the recommended "Sign requests" default. Never create an
`origin-access-identity` (OAI) — it is legacy.

### 2. Create the distribution pointing at the bucket's regional domain, with the OAC attached

Key fields in the distribution config: origin `DomainName` = `acme-site.s3.eu-west-1.amazonaws.com`,
`OriginAccessControlId` = the id above, `S3OriginConfig.OriginAccessIdentity` = empty string,
and the default cache behavior `ViewerProtocolPolicy` = `redirect-to-https`.

```bash
aws cloudfront create-distribution --distribution-config file://dist-config.json
# After creation, note the distribution ARN: arn:aws:cloudfront::123456789012:distribution/E123
```

### 3. Bucket policy — grant ONLY this distribution, bucket stays private

Block Public Access stays **on**. Access is granted purely by this resource policy, scoped to the
distribution ARN via `aws:SourceArn` (confused-deputy guard):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "AllowCloudFrontOACRead",
    "Effect": "Allow",
    "Principal": { "Service": "cloudfront.amazonaws.com" },
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::acme-site/*",
    "Condition": {
      "StringEquals": {
        "AWS:SourceArn": "arn:aws:cloudfront::123456789012:distribution/E123"
      }
    }
  }]
}
```

```bash
aws s3api put-bucket-policy --bucket acme-site --policy file://bucket-policy.json
```

### 4. Invalidations and custom domain

```bash
# Bust the cache after a deploy:
aws cloudfront create-invalidation --distribution-id E123 --paths "/*"
```

For a custom domain, request the **ACM certificate in `us-east-1`** (CloudFront only reads certs
from there, regardless of where your bucket and app live), validate it via DNS, then set the
distribution's `Aliases` + `ViewerCertificate.ACMCertificateArn`. Point the domain at the
distribution with a DNS alias/`CNAME`.
