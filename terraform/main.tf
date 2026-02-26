module "vpc" {
  source = "./modules/vpc"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  aws_region           = var.aws_region

  cluster_name = var.eks_name
}

module "ecr" {
  source = "./modules/ecr"

  repo_name   = var.ecr_repo_name
  name_prefix = local.name_prefix
}

module "eks" {
  source = "./modules/eks"

  name_prefix         = local.name_prefix
  eks_name            = var.eks_name
  cluster_version     = var.cluster_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_types = var.node_instance_types
  desired_size        = var.node_desired_size
  ami_type            = var.node_ami_type
  min_size            = var.node_min_size
  max_size            = var.node_max_size

  eks_access_entries = var.eks_access_entries
}
