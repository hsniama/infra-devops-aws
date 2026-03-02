# Security Controls Checklist (infra-devops-aws)

## Identity and Access
- OIDC federation from GitHub Actions to AWS STS.
- No static AWS keys in repository secrets.
- Dedicated IAM role for CI/CD with scoped trust policy.
- Least-privilege permissions policy attached to CI/CD role.
- EKS Access Entries configured for human and automation principals.

## Environment Governance
- Separate TEST and PROD environments.
- Manual approval required for PROD deployments/destroy.
- Branch-based deployment routing (`dev/**` -> TEST, `main` -> PROD).

## Terraform State Security
- Remote state in S3 bucket.
- State locking in DynamoDB.
- Separate state keys for TEST and PROD.

## Network Isolation
- Dedicated VPC per environment.
- Private subnets for EKS nodes.
- NAT gateway for controlled egress from private subnets.
- Public exposure minimized to required entry points.

## Suggested Hardening Next Steps
- Restrict EKS public endpoint CIDRs.
- Enable EKS control-plane logs to CloudWatch.
- Add IAM Access Analyzer and Config rules for drift/policy checks.
- Add image scanning gates for ECR artifacts in CI/CD.
