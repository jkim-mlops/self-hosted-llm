/**
 * # Deployment Configuration
 *
 * Deploys the self-hosted LLM infrastructure to AWS.
 *
 * ## Prerequisites
 *
 * 1. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in values
 *    (or run `task setup-tfvars` to auto-detect IAM user and SSO role)
 * 2. Download the model: `task download-model`
 * 3. Initialize Terraform: `terraform init`
 *
 * ## DNS Record Management
 *
 * The Route 53 A record pointing to the ALB is managed via Taskfile rather
 * than Terraform. This avoids a circular dependency: the ALB is created by
 * the AWS Load Balancer Controller (triggered by the Kubernetes Ingress),
 * not by Terraform directly. Managing the DNS record in Terraform would
 * require a `data` source lookup that fails on first apply.
 *
 * Use `task apply` and `task destroy` instead of raw terraform commands
 * to ensure DNS records are created/cleaned up properly.
 *
 * ## Tasks
 *
 * Run with `task <name>` from this directory.
 *
 * - `apply` - Apply terraform and create DNS record
 * - `destroy` - Full destroy - cleanup resources and run terraform destroy
 * - `setup-tfvars` - Create terraform.tfvars with IAM user and SSO role
 * - `download-model` - Download LLM model from HuggingFace to local models/ directory
 * - `cleanup` - Clean up resources that block terraform destroy
 * - `trivy` - Run security scan on Terraform and Docker configs
 * - `infracost` - Show cost estimate for infrastructure
 * - `smoke-test` - Run health checks after deployment
 * - `check` - Run all checks (trivy + infracost)
 */

data "aws_region" "this" {}

data "aws_iam_user" "this" {
  user_name = var.iam_user_name
}

data "aws_iam_role" "this" {
  name = var.admin_sso_role_name
}

module "main" {
  source = "./.."

  # General
  name   = "llm-${terraform.workspace}"
  region = data.aws_region.this.id

  # Networking
  cidr_block = "10.0.0.0/16"
  subnets = {
    a-public = {
      availability_zone = "${data.aws_region.this.id}a"
      cidr_block        = "10.0.1.0/24"
      public            = true
    }
    b-public = {
      availability_zone = "${data.aws_region.this.id}b"
      cidr_block        = "10.0.2.0/24"
      public            = true
    }
    a-private = {
      availability_zone = "${data.aws_region.this.id}a"
      cidr_block        = "10.0.3.0/24"
      public            = false
    }
    b-private = {
      availability_zone = "${data.aws_region.this.id}b"
      cidr_block        = "10.0.4.0/24"
      public            = false
    }
  }

  admin_users = [
    data.aws_iam_user.this.arn,
    data.aws_iam_role.this.arn
  ]

  # Node scaling
  cpu_node_desired_size = 1
  gpu_node_desired_size = var.gpu_node_desired_size

  # Domain configuration
  domain_name      = var.domain_name
  hosted_zone_name = var.hosted_zone_name

  # Model configuration
  model_id        = var.model_id
  model_s3_prefix = var.model_s3_prefix

  # Application scaling
  vllm_replicas    = var.vllm_replicas
  chatbot_replicas = var.chatbot_replicas
}