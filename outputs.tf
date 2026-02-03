# EKS Cluster Outputs
output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster.name
}

output "eks_cluster_endpoint" {
  description = "API endpoint for the EKS cluster"
  value       = module.eks.cluster.endpoint
}

output "eks_cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for cluster authentication"
  value       = module.eks.cluster.certificate_authority[0].data
  sensitive   = true
}

output "eks_cluster_oidc_issuer" {
  description = "OIDC issuer URL for IAM Roles for Service Accounts (IRSA)"
  value       = module.eks.cluster.identity[0].oidc[0].issuer
}

# IAM Outputs
output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

# Networking Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs for ALB placement"
  value       = module.vpc.public_subnet_ids
}

output "alb_security_group_id" {
  description = "Security group ID for the Application Load Balancer"
  value       = aws_security_group.alb.id
}

# Container Image Outputs
output "chatbot_image_url" {
  description = "ECR repository URL for the chatbot image (with digest)"
  value       = "${module.chatbot.ecr_repo.repository_url}@${module.chatbot.image.sha256_digest}"
}

output "vllm_server_image_url" {
  description = "ECR repository URL for the vLLM server image (with digest)"
  value       = "${module.vllm-server.ecr_repo.repository_url}@${module.vllm-server.image.sha256_digest}"
}

# Certificate Outputs
output "acm_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS"
  value       = aws_acm_certificate.chatbot.arn
}

# DNS Outputs
output "route53_zone_id" {
  description = "Route 53 hosted zone ID"
  value       = data.aws_route53_zone.main.zone_id
}

# S3 Outputs
output "model_bucket_name" {
  description = "S3 bucket name for LLM model storage"
  value       = aws_s3_bucket.model.id
}

output "model_bucket_arn" {
  description = "S3 bucket ARN for LLM model storage"
  value       = aws_s3_bucket.model.arn
}

# vLLM IAM Outputs
output "vllm_role_arn" {
  description = "IAM role ARN for vLLM pods"
  value       = aws_iam_role.vllm.arn
}
