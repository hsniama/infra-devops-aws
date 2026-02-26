aws_region  = "us-east-1"
environment = "prod"
project     = "infra-aws"

vpc_cidr             = "10.111.0.0/16"
public_subnet_cidrs  = ["10.111.10.0/24", "10.111.11.0/24"]
private_subnet_cidrs = ["10.111.20.0/24", "10.111.21.0/24"]

eks_name      = "eksdevops1720prod" // nombre del clúster EKS a tu elección. Es único a nivel global.
cluster_version = "1.33" // versión de Kubernetes que correrá en EKS
ecr_repo_name = "ecrdevops1720prod" // nombre del repositorio ECR a tu elección. Es único a nivel global.

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
node_ami_type       = "BOTTLEROCKET_x86_64" // Elegir el tipo de AMI que desees para los nodos del clúster. BOTTLEROCKET_x86_64 es una buena opción optimizada para EKS, pero también puedes usar por ejemplo AL2_x86_64 o AL2_ARM_64 dependiendo de tus necesidades y preferencias.

tags = {
  project = "infra-aws"
  owner   = "henry"
  env     = "prod"
}
