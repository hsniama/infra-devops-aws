#!/usr/bin/env bash
set -euo pipefail

REGION="${1:-us-east-1}"
BUCKET="${2:?Usage: $0 <region> <bucket_name> <dynamodb_table>}"
DDB_TABLE="${3:-tfstate-locks-devops}"

echo "==> Emptying ALL objects, versions, and delete markers from bucket: ${BUCKET}"

delete_all_versions() {
  local bucket=$1
  local region=$2
  local deleted_count=0

  while true; do
    output=$(aws s3api list-object-versions \
      --bucket "$bucket" \
      --region "$region" \
      --max-items 1000 2>/dev/null || true)

    objects=$(echo "$output" | jq -c '[.Versions[]?, .DeleteMarkers[]?] | map({Key:.Key, VersionId:.VersionId})')

    if [[ "$objects" == "[]" ]]; then
      break
    fi

    result=$(aws s3api delete-objects \
      --bucket "$bucket" \
      --region "$region" \
      --delete "{\"Objects\":$objects}" || true)

    count=$(echo "$result" | jq '.Deleted | length')
    deleted_count=$((deleted_count + count))
    echo "   -> Deleted $count objects in this batch (total: $deleted_count)"
  done

  echo "==> Finished deleting $deleted_count objects/versions from bucket: $bucket"
}

delete_all_versions "$BUCKET" "$REGION"

echo "==> Deleting bucket: ${BUCKET}"
aws s3api delete-bucket --bucket "${BUCKET}" --region "${REGION}"
echo "   -> Bucket '${BUCKET}' deleted successfully."

echo "==> Deleting DynamoDB table: ${DDB_TABLE}"
aws dynamodb delete-table --table-name "${DDB_TABLE}" --region "${REGION}" || true

echo "==> Waiting for DynamoDB table to be deleted..."
while true; do
  STATUS=$(aws dynamodb describe-table \
    --table-name "${DDB_TABLE}" \
    --region "${REGION}" \
    --query "Table.TableStatus" \
    --output text 2>/dev/null || echo "NOT_FOUND")
  if [[ "$STATUS" == "NOT_FOUND" ]]; then
    echo "   -> DynamoDB table '${DDB_TABLE}' deleted successfully."
    break
  fi
  echo "   -> Current status: $STATUS"
  sleep 5
done

echo "DONE. Backend resources destroyed."





# Se ejecuta así
# chmod +x scripts/destroy_backend.sh
# ./scripts/destroy_backend.sh <region> <bucket_name> <dynamodb_table>
# En mi caso:
# ./scripts/destroy_backend.sh us-east-1 tfstate-devops-henry-1720 tfstate-locks-devops

