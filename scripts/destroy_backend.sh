#!/usr/bin/env bash
set -euo pipefail

REGION="${1:-us-east-1}"
BUCKET="${2:?Usage: $0 <region> <bucket_name> <dynamodb_table>}"
DDB_TABLE="${3:-tfstate-locks-devops}"

echo "==> Emptying S3 bucket: ${BUCKET}"
aws s3 rm "s3://${BUCKET}" --recursive --region "${REGION}" || true

echo "==> Deleting S3 bucket: ${BUCKET}"
aws s3api delete-bucket --bucket "${BUCKET}" --region "${REGION}" || true

echo "==> Deleting DynamoDB table: ${DDB_TABLE}"
aws dynamodb delete-table --table-name "${DDB_TABLE}" --region "${REGION}" || true

echo "DONE."
