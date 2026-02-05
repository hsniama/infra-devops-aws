#!/usr/bin/env bash
set -euo pipefail

ACCOUNT_ID="${1:?Usage: $0 <account_id> <role_name> <policy_name>}"
ROLE_NAME="${2:-gh-oidc-terraform-infra-devops-aws}"
POLICY_NAME="${3:-gh-oidc-terraform-infra-devops-aws-policy}"

OIDC_URL="token.actions.githubusercontent.com"
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_URL}"
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

echo "==> Detaching policy from role (if attached)..."
aws iam detach-role-policy --role-name "${ROLE_NAME}" --policy-arn "${POLICY_ARN}" >/dev/null 2>&1 

echo "==> Deleting inline policies (if any)..."
for p in $(aws iam list-role-policies --role-name "${ROLE_NAME}" --query "PolicyNames[]" --output text); do
  echo "   - Deleting inline policy: $p"
  aws iam delete-role-policy --role-name "${ROLE_NAME}" --policy-name "$p"
done

echo "==> Removing role from instance profiles (if any)..."
for ip in $(aws iam list-instance-profiles-for-role --role-name "${ROLE_NAME}" --query "InstanceProfiles[].InstanceProfileName" --output text); do
  echo "   - Removing from instance profile: $ip"
  aws iam remove-role-from-instance-profile --instance-profile-name "$ip" --role-name "${ROLE_NAME}" 
  aws iam delete-instance-profile --instance-profile-name "$ip" 
done

echo "==> Deleting role (if exists)..."
aws iam delete-role --role-name "${ROLE_NAME}" >/dev/null 2>&1 

echo "==> Deleting policy versions (non-default)..."
if aws iam get-policy --policy-arn "${POLICY_ARN}" >/dev/null 2>&1; then
  VERSIONS=$(aws iam list-policy-versions --policy-arn "${POLICY_ARN}" --query "Versions[?IsDefaultVersion==\`false\`].VersionId" --output text || true)
  for v in ${VERSIONS}; do
    echo "   - Deleting policy version: $v"
    aws iam delete-policy-version --policy-arn "${POLICY_ARN}" --version-id "${v}"
  done

  echo "==> Deleting policy..."
  aws iam delete-policy --policy-arn "${POLICY_ARN}"
fi

echo "==> Deleting OIDC provider (if exists)..."
aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_ARN}" >/dev/null 2>&1

echo "DONE."


# Se ejecuta así
# chmod +x scripts/destroy_oidc.sh
# scripts/destroy_oidc.sh <account_id> <role_name> <policy_name>
# En mi caso:
# ./scripts/destroy_oidc.sh 035462351040 gh-oidc-terraform-infra-devops-aws gh-oidc-terraform-infra-devops-aws-policy
