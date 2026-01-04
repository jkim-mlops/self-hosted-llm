variable "admin_sso_role_name" {
  description = "Name of the AWS SSO AdministratorAccess role"
  type        = string
}

variable "iam_user_name" {
  description = "Name of the IAM user for cluster admin access"
  type        = string
}
