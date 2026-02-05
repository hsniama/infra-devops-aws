#!/usr/bin/env bash
set -euo pipefail

REGION="${1:-us-east-1}"
BUCKET="${2:?Usage: $0 <region> <bucket_name> <dynamodb_table>}"
DDB_TABLE="${3:-tfstate-locks-devops}"

echo "==> Emptying S3 bucket: ${BUCKET}"
aws s3 rm "s3://${BUCKET}" --recursive --region "${REGION}"

echo "==> Deleting S3 bucket: ${BUCKET}"
aws s3api delete-bucket --bucket "${BUCKET}" --region "${REGION}"

# DESTRUCCIÓN
echo "==> Deleting DynamoDB table: ${DDB_TABLE}"
aws dynamodb delete-table --table-name "${DDB_TABLE}" --region "${REGION}" || true

echo "==> Waiting for DynamoDB table to be deleted..."
while true; do
  STATUS=$(aws dynamodb describe-table \
    --table-name "${DDB_TABLE}" \
    --region "${REGION}" \
    --query "Table.TableStatus" \
    --output text 2>/dev/null || echo "NOT_FOUND")
  echo "Current status: $STATUS"
  if [[ "$STATUS" == "NOT_FOUND" ]]; then
    break
  fi
  sleep 5
done

echo "DONE."


# Se ejecuta así
# chmod +x scripts/destroy_backend.sh
# ./scripts/destroy_backend.sh <region> <bucket_name> <dynamodb_table>
# En mi caso:
# ./scripts/destroy_backend.sh us-east-1 tfstate-devops-henry-1720 tfstate-locks-devops

