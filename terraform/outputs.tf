output "vpc_id" {
  value = module.vpc.vpc_id
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "eks_name" {
  value = module.eks.eks_name
}

output "eks_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_oidc_issuer" {
  value = module.eks.oidc_issuer_url
}