variable "name_prefix" {
  type = string
}
variable "aws_region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "cluster_name" {
  type        = string
  description = "Nombre del cluster EKS para tagging de subnets"
}
