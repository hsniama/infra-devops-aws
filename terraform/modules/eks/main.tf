module "eks" {
  source  = "terraform-aws-modules/eks/aws" // viene del Terraform Registry
  version = "~> 20.0"

  cluster_name    = var.eks_name
  cluster_version = "1.29" // versión de Kubernetes que correrá en EKS

  vpc_id     = var.vpc_id             //  ID de la VPC donde se desplegará el clúster.
  subnet_ids = var.private_subnet_ids // lista de subnets privadas donde se ubicarán los nodos del clúster.

  #Para poder usar kubectl desde fuera (nuestra laptop / GitHub runners si hace falta)
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  // ---------------------------------------------------------
  # De aquí en adelante, configuramos la autorización para acceder al clúster EKS con nuestro usuario IAM o grupo.
  # habilitación access entries + compat con aws-auth 
  authentication_mode = "API_AND_CONFIG_MAP"

  access_entries = {
    terraform_user_admin = {
      principal_arn = var.user_eks_admin_arn
      policy_association = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    # también dejamos de admin al role OIDC que crea/despliega
    github_oidc_admin = {
      principal_arn = "arn:aws:iam::035462351040:role/gh-oidc-terraform-infra-devops-aws"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  eks_managed_node_groups = { //  define los grupos de nodos (EC2) que EKS administrará automáticamente.
    default = {
      instance_types = var.node_instance_types
      min_size       = var.min_size
      max_size       = var.max_size
      desired_size   = var.desired_size
    }
  }

}
