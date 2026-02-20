aws_region  = "us-east-1"
environment = "test"
project     = "infra-aws"

vpc_cidr             = "10.110.0.0/16"
public_subnet_cidrs  = ["10.110.10.0/24", "10.110.11.0/24"]
private_subnet_cidrs = ["10.110.20.0/24", "10.110.21.0/24"]

eks_name      = "eksdevops1720test" // nombre del clúster EKS a tu elección. Es único a nivel global.
ecr_repo_name = "ecrdevops1720test" // nombre del repositorio ECR a tu elección. Es único a nivel global.

eks_access_entries = {
  terraform_user = {
    principal_arn = "arn:aws:iam::035462351040:user/terraformUser" // Poner el ARN de tu usuario IAM de administración de EKS
    policies = {
      admin = {
        policy_arn        = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope_type = "cluster"
      }
      readonly = {
        policy_arn        = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
        access_scope_type = "cluster"
      }
    }
  }
  github_oidc = {
    principal_arn = "arn:aws:iam::035462351040:role/gh-oidc-terraform-infra-devops-aws" // Poner el ARN del role OIDC de GitHub Actions
    policies = {
      admin = {
        policy_arn        = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope_type = "cluster"
      }
    }
  }
}

node_instance_types = ["t3.medium"] // poner los tipos de instancia que desees para los nodos del clúster
node_desired_size   = 2
node_min_size       = 2
node_max_size       = 5
node_ami_type       = "BOTTLEROCKET_x86_64"

tags = {
  project = "infra-aws"
  owner   = "henry"
  env     = "test"
}