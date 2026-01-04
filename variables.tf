variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for VPC"
  type        = string
}

variable "subnets" {
  description = "Map of subnet configurations"
  type = map(object({
    availability_zone = string
    cidr_block        = string
    public            = bool
  }))
}

variable "admin_users" {
  description = "List of IAM user/role ARNs for cluster admin access"
  type        = list(string)
}

variable "cpu_node_desired_size" {
  description = "Desired number of CPU nodes"
  type        = number
}

variable "gpu_node_desired_size" {
  description = "Desired number of GPU nodes"
  type        = number
}
