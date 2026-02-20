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
  default = "infra-aws"
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

variable "node_ami_type" {
  type = string
}

variable "ecr_repo_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "eks_access_entries" {
  description = "Mapa de usuarios/roles con sus policies para acceso al cluster EKS"
  type = map(object({
    principal_arn = string
    policies = map(object({
      policy_arn        = string
      access_scope_type = string
    }))
  }))
}
