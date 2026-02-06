variable "aws_region" {
  type = string
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["test", "prod"], var.environment)
    error_message = "environment must be 'test' or 'prod'."
  }
}

variable "project" {
  type    = string
  default = "devops-aws"
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

variable "eks_name" {
  type = string
}

variable "node_instance_types" {
  type = list(string)
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 5
}

variable "ecr_repo_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "user_eks_admin_arn" {
  type = string
}
