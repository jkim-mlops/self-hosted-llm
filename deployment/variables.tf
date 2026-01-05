variable "admin_sso_role_name" {
  description = "Name of the AWS SSO AdministratorAccess role"
  type        = string
}

variable "iam_user_name" {
  description = "Name of the IAM user for cluster admin access"
  type        = string
}

variable "gpu_node_desired_size" {
  description = "Desired number of GPU nodes in the EKS cluster"
  type        = number
}

variable "domain_name" {
  description = "Domain name for the chatbot application"
  type        = string
}
