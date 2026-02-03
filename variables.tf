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

# -----------------------------------------------------------------------------
# Domain and DNS Configuration
# -----------------------------------------------------------------------------
variable "domain_name" {
  description = "Domain name for the chatbot application (e.g., chatbot.dev.jkim.ai)"
  type        = string
}

variable "hosted_zone_name" {
  description = "Route 53 hosted zone name (e.g., jkim.ai)"
  type        = string
}

# -----------------------------------------------------------------------------
# Application Scaling Configuration
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Model Configuration
# -----------------------------------------------------------------------------
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
