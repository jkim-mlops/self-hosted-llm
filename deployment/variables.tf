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

variable "hosted_zone_name" {
  description = "Route 53 hosted zone name (e.g., jkim.ai)"
  type        = string
}

variable "model_id" {
  description = "HuggingFace model ID (e.g., Qwen/Qwen2.5-1.5B-Instruct)"
  type        = string
  default     = "Qwen/Qwen2.5-1.5B-Instruct"
}

variable "model_s3_prefix" {
  description = "S3 prefix path to the model files"
  type        = string
  default     = "models"
}

variable "vllm_replicas" {
  description = "Number of vLLM inference server replicas"
  type        = number
  default     = 1
}

variable "chatbot_replicas" {
  description = "Number of chatbot frontend replicas"
  type        = number
  default     = 2
}
