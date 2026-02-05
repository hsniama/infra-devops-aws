aws_region  = "us-east-1"
environment = "test"
project     = "devops-aws"

vpc_cidr             = "10.110.0.0/16"
public_subnet_cidrs  = ["10.110.10.0/24", "10.110.11.0/24"]
private_subnet_cidrs = ["10.110.20.0/24", "10.110.21.0/24"]

eks_name                = "eksdevops1720test"
ecr_repo_name           = "devops-microservice-test"
eks_public_access_cidrs = ["149.50.197.136/32"] // Aqui agregas tu IP pública para acceder al endpoint público de EKS. Usar curl ifconfig.me para saber tu IP.  

node_instance_types = ["t3.medium"]
node_desired_size   = 2
node_min_size       = 2
node_max_size       = 5

tags = {
  project = "devops-aws"
  owner   = "henry"
  env     = "test"
}
