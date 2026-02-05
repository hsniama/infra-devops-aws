module "eks" {
  source  = "terraform-aws-modules/eks/aws" // viene del Terraform Registry
  version = "~> 20.0"

  cluster_name    = var.eks_name
  cluster_version = "1.29" // versión de Kubernetes que correrá en EKS

  vpc_id     = var.vpc_id             //  ID de la VPC donde se desplegará el clúster.
  subnet_ids = var.private_subnet_ids // lista de subnets privadas donde se ubicarán los nodos del clúster.

  # Para poder usar kubectl desde fuera (mi laptop)
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Recomendado: restringe el acceso público a tu IP
  cluster_endpoint_public_access_cidrs = var.eks_public_access_cidrs

  // Los nodos suelen estar en subnets privadas para mayor seguridad, mientras que los balanceadores se crean en subnets públicas.

  eks_managed_node_groups = { //  define los grupos de nodos (EC2) que EKS administrará automáticamente.
    default = {
      instance_types = var.node_instance_types
      min_size       = var.min_size
      max_size       = var.max_size
      desired_size   = var.desired_size
    }
  }
}
