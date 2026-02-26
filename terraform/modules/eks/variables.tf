variable "name_prefix" {
  type = string
}

variable "eks_name" {
  type = string
}

variable cluster_version {
  type    = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "node_instance_types" {
  type = list(string)
}

variable "desired_size" {
  type = number
}

variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "ami_type" {
  type = string
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

