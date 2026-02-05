#!/usr/bin/env bash
set -euo pipefail

REGION="${1:-us-east-1}"
BUCKET="${2:-tfstate-devops-henry-1720}"
DDB_TABLE="${3:-tfstate-locks-devops}"

echo "==> Checking if S3 bucket ${BUCKET} exists..."
if aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "Bucket ${BUCKET} already exists, skipping creation."
else
  echo "==> Creating S3 bucket: ${BUCKET} in ${REGION}"
  if [[ "${REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}"
  else
    aws s3api create-bucket \
      --bucket "${BUCKET}" \
      --region "${REGION}" \
      --create-bucket-configuration LocationConstraint="${REGION}"
  fi
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

echo "==> Checking if DynamoDB table ${DDB_TABLE} exists..."
if aws dynamodb describe-table --table-name "${DDB_TABLE}" --region "${REGION}" >/dev/null 2>&1; then
  echo "Table ${DDB_TABLE} already exists, skipping creation."
else
# CREACIÓN
echo "==> Creating DynamoDB lock table: ${DDB_TABLE}"
aws dynamodb create-table \
  --table-name "${DDB_TABLE}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "${REGION}"

echo "==> Waiting for DynamoDB table to be ACTIVE..."
while true; do
  STATUS=$(aws dynamodb describe-table \
    --table-name "${DDB_TABLE}" \
    --region "${REGION}" \
    --query "Table.TableStatus" \
    --output text 2>/dev/null || echo "NOT_FOUND")
  echo "Current status: $STATUS"
  if [[ "$STATUS" == "ACTIVE" ]]; then
    break
  fi
  sleep 5
done
fi



# Se ejecuta com:
# chmod +x scripts/bootstrap_backend.sh
# scripts/bootstrap_backend.sh <region> <bucket_name> <dynamodb_table>
# En mi caso:
# ./scripts/bootstrap_backend.sh us-east-1 tfstate-devops-henry-1720 tfstate-locks-devops