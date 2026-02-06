aws_region  = "us-east-1"
environment = "prod"
project     = "devops-aws"

vpc_cidr             = "10.111.0.0/16"
public_subnet_cidrs  = ["10.111.10.0/24", "10.111.11.0/24"]
private_subnet_cidrs = ["10.111.20.0/24", "10.111.21.0/24"]

eks_name      = "eksdevops1720prod"
ecr_repo_name = "devops-microservice-prod"

node_instance_types = ["t3.medium"]
node_desired_size   = 2
node_min_size       = 2
node_max_size       = 5

tags = {
  project = "devops-aws"
  owner   = "henry"
  env     = "prod"
}
