#!/usr/bin/env bash
set -euo pipefail

ACCOUNT_ID="${1:?Usage: $0 <account_id> <role_name> <policy_name>}"
ROLE_NAME="${2:-gh-oidc-terraform-infra-devops-aws}"
POLICY_NAME="${3:-gh-oidc-terraform-infra-devops-aws-policy}"

POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

echo "==> Detaching policy from role (if attached)..."
aws iam detach-role-policy --role-name "${ROLE_NAME}" --policy-arn "${POLICY_ARN}" >/dev/null 2>&1 || true

echo "==> Deleting role (if exists)..."
aws iam delete-role --role-name "${ROLE_NAME}" >/dev/null 2>&1 || true

echo "==> Deleting policy (if exists)..."
# Must delete non-default versions first if exist
if aws iam get-policy --policy-arn "${POLICY_ARN}" >/dev/null 2>&1; then
  VERSIONS=$(aws iam list-policy-versions --policy-arn "${POLICY_ARN}" --query "Versions[?IsDefaultVersion==\`false\`].VersionId" -o text || true)
  for v in ${VERSIONS}; do
    aws iam delete-policy-version --policy-arn "${POLICY_ARN}" --version-id "${v}" >/dev/null || true
  done
  aws iam delete-policy --policy-arn "${POLICY_ARN}" >/dev/null || true
fi

echo "DONE."


# Se ejecuta así
# chmod +x scripts/destroy_oidc.sh
# scripts/destroy_oidc.sh <account_id> <role_name> <policy_name>
# En mi caso:
# ./scripts/destroy_oidc.sh 035462351040 gh-oidc-terraform-infra-devops-aws gh-oidc-terraform-infra-devops-aws-policy
