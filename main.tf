module "vpc" {
  source = "git@github.com:jkim-mlops/terraform-modules.git//modules/vpc?ref=0.2.0"

  name       = var.name
  region     = var.region
  cidr_block = var.cidr_block
  subnets    = var.subnets
}

module "eks" {
  source = "git@github.com:jkim-mlops/terraform-modules.git//modules/eks?ref=feat/eks"

  name               = var.name
  subnet_ids         = module.vpc.private_subnet_ids
  kubernetes_version = "1.32"

  # CPU Node Group Configuration (for general workloads)
  cpu_node_group = {
    instance_types = ["t3.medium"]
    disk_size      = 50
    desired_size   = var.cpu_node_desired_size
    max_size       = 2
    min_size       = 0
    ami_type       = "BOTTLEROCKET_x86_64"
    capacity_type  = "ON_DEMAND"
  }

  # GPU Node Group Configuration (for AI/ML workloads)
  gpu_node_group = {
    instance_types = ["g5.2xlarge"] # 8 vCPUs, 32GiB memory, 1x NVIDIA A10G GPU
    disk_size      = 100
    desired_size   = var.gpu_node_desired_size
    max_size       = 2
    min_size       = 0
    ami_type       = "AL2_x86_64_GPU" # GPU-optimized Amazon Linux 2
    capacity_type  = "ON_DEMAND"
  }

  # Add your SSO role as cluster admin
  admin_users = var.admin_users
}

module "chatbot" {
  source = "git@github.com:jkim-mlops/terraform-modules.git//modules/docker?ref=0.2.0"

  image_name    = "chatbot"
  image_tag     = "0.1.0"
  build_context = "../images/chatbot"
  platform     = "linux/amd64"
}

module "vllm-server" {
  source = "git@github.com:jkim-mlops/terraform-modules.git//modules/docker?ref=0.2.0"

  image_name    = "vllm-server"
  image_tag     = "0.1.0"
  build_context = "../images/vllm-server"
  platform      = "linux/amd64"
}

# -----------------------------------------------------------------------------
# OIDC Provider for IAM Roles for Service Accounts (IRSA)
# -----------------------------------------------------------------------------
data "tls_certificate" "eks" {
  url = module.eks.cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = module.eks.cluster.identity[0].oidc[0].issuer

  tags = {
    Name = "${var.name}-eks-oidc"
  }
}

# -----------------------------------------------------------------------------
# ALB Security Group
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP for HTTPS redirect"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-alb-sg"
  }
}

# -----------------------------------------------------------------------------
# ACM Certificate for HTTPS
# -----------------------------------------------------------------------------
resource "aws_acm_certificate" "chatbot" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = {
    Name = var.domain_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Route 53 DNS Validation for ACM Certificate
# -----------------------------------------------------------------------------
data "aws_route53_zone" "main" {
  name         = var.hosted_zone_name
  private_zone = false
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.chatbot.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

resource "aws_acm_certificate_validation" "chatbot" {
  certificate_arn         = aws_acm_certificate.chatbot.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# -----------------------------------------------------------------------------
# S3 Bucket for LLM Model Storage
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "model" {
  bucket        = "${var.name}-llm-models"
  force_destroy = true # Allow bucket deletion even with objects/versions

  tags = {
    Name = "${var.name}-llm-models"
  }
}

resource "aws_s3_bucket_versioning" "model" {
  bucket = aws_s3_bucket.model.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "model" {
  bucket = aws_s3_bucket.model.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "model" {
  bucket = aws_s3_bucket.model.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# IAM Role for vLLM Pod to Access S3 (IRSA)
# -----------------------------------------------------------------------------
resource "aws_iam_policy" "vllm_s3_access" {
  name        = "${var.name}-vllm-s3-access"
  description = "IAM policy for vLLM pods to download models from S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.model.arn,
          "${aws_s3_bucket.model.arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name = "${var.name}-vllm-s3-access"
  }
}

resource "aws_iam_role" "vllm" {
  name        = "${var.name}-vllm"
  description = "IAM role for vLLM pods using IRSA"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:llm:vllm"
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Name = "${var.name}-vllm-role"
  }
}

resource "aws_iam_role_policy_attachment" "vllm_s3_access" {
  policy_arn = aws_iam_policy.vllm_s3_access.arn
  role       = aws_iam_role.vllm.name
}

# -----------------------------------------------------------------------------
# Sync Local Model Files to S3
# -----------------------------------------------------------------------------
resource "terraform_data" "model_sync" {
  triggers_replace = [
    filemd5("${path.module}/models/${var.model_id}/config.json")
  ]

  provisioner "local-exec" {
    command = "aws s3 sync ${path.module}/models/${var.model_id} s3://${aws_s3_bucket.model.id}/${var.model_s3_prefix}/"
  }

  depends_on = [aws_s3_bucket.model]
}
