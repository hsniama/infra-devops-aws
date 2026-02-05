#!/usr/bin/env bash
set -euo pipefail

ACCOUNT_ID="${1:?Usage: $0 <account_id> <repo_full_name> <role_name> <region>}"
REPO_FULL="${2:?Usage: $0 <account_id> <repo_full_name> <role_name> <region>}"
ROLE_NAME="${3:-gh-oidc-terraform-infra-devops-aws}"
REGION="${4:-us-east-1}"

OIDC_URL="token.actions.githubusercontent.com"
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_URL}"

echo "==> Using:"
echo "ACCOUNT_ID=${ACCOUNT_ID}"
echo "REPO_FULL=${REPO_FULL}" # example: hsniama/infra-devops-aws
echo "ROLE_NAME=${ROLE_NAME}"
echo "REGION=${REGION}"
echo

# 1) Create OIDC provider if not exists
echo "==> Ensuring GitHub OIDC provider exists..."
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_ARN}" >/dev/null 2>&1; then
  echo "OIDC provider already exists: ${OIDC_ARN}"
else
  # GitHub OIDC thumbprint is commonly this (root CA). AWS CLI requires one.
  # This works in practice for GitHub Actions OIDC.
  THUMBPRINT="6938fd4d98bab03faadb97b34396831e3780aea1"

  aws iam create-open-id-connect-provider \
    --url "https://${OIDC_URL}" \
    --client-id-list "sts.amazonaws.com" \
    --thumbprint-list "${THUMBPRINT}" >/dev/null

  echo "OIDC provider created: ${OIDC_ARN}"
fi

# 2) Create trust policy for repo (only this repo, and only specific branches)
#    - Allow main and test/** pushes (matches your workflow logic)
TMP_TRUST="$(mktemp)"
cat > "${TMP_TRUST}" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Federated": "${OIDC_ARN}" },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_URL}:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "${OIDC_URL}:sub": [
            "repo:${REPO_FULL}:ref:refs/heads/main",
            "repo:${REPO_FULL}:ref:refs/heads/dev/*",
            "repo:${REPO_FULL}:pull_request"
          ]
        }
      }
    }
  ]
}
EOF

echo "==> Creating/updating role: ${ROLE_NAME}"
if aws iam get-role --role-name "${ROLE_NAME}" >/dev/null 2>&1; then
  aws iam update-assume-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-document "file://${TMP_TRUST}" >/dev/null
  echo "Role trust policy updated."
else
  aws iam create-role \
    --role-name "${ROLE_NAME}" \
    --assume-role-policy-document "file://${TMP_TRUST}" >/dev/null
  echo "Role created."
fi

rm -f "${TMP_TRUST}"

# 3) Create/Update permissions policy and attach to role
POLICY_NAME="gh-oidc-terraform-infra-devops-aws-policy"
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

TMP_POLICY="$(mktemp)"
cat > "${TMP_POLICY}" <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformStateS3",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning",
        "s3:GetEncryptionConfiguration",
        "s3:PutEncryptionConfiguration",
        "s3:GetBucketPublicAccessBlock",
        "s3:PutBucketPublicAccessBlock",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "*"
    },
    {
      "Sid": "TerraformLockDynamoDB",
      "Effect": "Allow",
      "Action": [
        "dynamodb:CreateTable",
        "dynamodb:DescribeTable",
        "dynamodb:DeleteTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:UpdateItem"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECR",
      "Effect": "Allow",
      "Action": [
        "ecr:CreateRepository",
        "ecr:DeleteRepository",
        "ecr:DescribeRepositories",
        "ecr:GetAuthorizationToken",
        "ecr:PutImageScanningConfiguration",
        "ecr:SetRepositoryPolicy",
        "ecr:TagResource",
        "ecr:UntagResource",
        "ecr:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "VPCAndNetworking",
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "elasticloadbalancing:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EKSAndIAM",
      "Effect": "Allow",
      "Action": [
        "eks:*",
        "iam:*",
        "autoscaling:*",
        "logs:*",
        "kms:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

echo "==> Ensuring policy exists: ${POLICY_NAME}"
if aws iam get-policy --policy-arn "${POLICY_ARN}" >/dev/null 2>&1; then
  # Create new policy version and set as default
  aws iam create-policy-version \
    --policy-arn "${POLICY_ARN}" \
    --policy-document "file://${TMP_POLICY}" \
    --set-as-default >/dev/null
  echo "Policy updated (new default version)."
else
  aws iam create-policy \
    --policy-name "${POLICY_NAME}" \
    --policy-document "file://${TMP_POLICY}" >/dev/null
  echo "Policy created."
fi

rm -f "${TMP_POLICY}"

echo "==> Attaching policy to role..."
aws iam attach-role-policy --role-name "${ROLE_NAME}" --policy-arn "${POLICY_ARN}" >/dev/null || true

echo
echo "DONE."
echo "Set this GitHub secret in infra-devops-aws repo:"
echo "AWS_ROLE_TO_ASSUME = arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# Este script
# crea/valida el OIDC Provider de GitHub (token.actions.githubusercontent.com)
# crea un Role con trust policy limitado a este repo
# adjunta una policy (mínimo viable para: VPC + EKS + ECR + S3 backend + DynamoDB lock)

# Se ejecuta con:
# chmod +x scripts/bootstrap_oidc.sh
# scripts/bootstrap_oidc.sh <account_id> <repo_full_name> <role_name> <region>
# En mi caso:
# ./scripts/bootstrap_oidc.sh 035462351040 hsniama/infra-devops-aws gh-oidc-terraform-infra-devops-aws us-east-1