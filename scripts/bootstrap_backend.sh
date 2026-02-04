# crea bucket + dynamodb
#!/usr/bin/env bash
set -euo pipefail

REGION="${1:-us-east-1}"
BUCKET="${2:-tfstate-devops-henry-1720}"
DDB_TABLE="${3:-tfstate-locks-devops}"

echo "==> Creating S3 bucket: ${BUCKET} in ${REGION}"

aws s3api create-bucket \
  --bucket "${BUCKET}" \
  --region "${REGION}" \
  --create-bucket-configuration LocationConstraint="${REGION}" 2>/dev/null \
  || true

# Si es us-east-1, AWS no permite LocationConstraint
if [[ "${REGION}" == "us-east-1" ]]; then
  aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}" 2>/dev/null || true
fi

echo "==> Enabling versioning"
aws s3api put-bucket-versioning \
  --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled

echo "==> Enabling encryption"
aws s3api put-bucket-encryption \
  --bucket "${BUCKET}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "AES256" }
    }]
  }'

echo "==> Blocking public access"
aws s3api put-public-access-block \
  --bucket "${BUCKET}" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "==> Creating DynamoDB lock table: ${DDB_TABLE}"
aws dynamodb create-table \
  --table-name "${DDB_TABLE}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "${REGION}" 2>/dev/null \
  || true

echo "DONE."


# Se ejecuta com:
# chmod +x scripts/bootstrap_backend.sh
# scripts/bootstrap_backend.sh <region> <bucket_name> <dynamodb_table>
# En mi caso:
# ./scripts/bootstrap_backend.sh us-east-1 tfstate-devops-henry-1720 tfstate-locks-devops