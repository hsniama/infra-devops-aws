aws_region  = "us-east-1"
environment = "test"
project     = "devops-aws"

vpc_cidr             = "10.110.0.0/16"
public_subnet_cidrs  = ["10.110.10.0/24", "10.110.11.0/24"]
private_subnet_cidrs = ["10.110.20.0/24", "10.110.21.0/24"]

eks_name           = "eksdevops1720test"                            // nombre del clúster EKS a tu elección
user_eks_admin_arn = "arn:aws:iam::035462351040:user/terraformUser" // Poner el ARN de tu usuario IAM de administración de EKS
ecr_repo_name      = "devops-microservice-test"                     // nombre del repositorio ECR a tu elección

node_instance_types = ["t3.medium"] // poner los tipos de instancia que desees para los nodos del clúster
node_desired_size   = 2
node_min_size       = 2
node_max_size       = 5

tags = {
  project = "devops-aws"
  owner   = "henry"
  env     = "test"
}