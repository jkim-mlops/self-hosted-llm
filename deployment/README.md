<!-- BEGIN_TF_DOCS -->
# Deployment Configuration

Deploys the self-hosted LLM infrastructure to AWS.

## Prerequisites

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in values
   (or run `task setup-tfvars` to auto-detect IAM user and SSO role)
2. Download the model: `task download-model`
3. Initialize Terraform: `terraform init`

## DNS Record Management

The Route 53 A record pointing to the ALB is managed via Taskfile rather
than Terraform. This avoids a circular dependency: the ALB is created by
the AWS Load Balancer Controller (triggered by the Kubernetes Ingress),
not by Terraform directly. Managing the DNS record in Terraform would
require a `data` source lookup that fails on first apply.

Use `task apply` and `task destroy` instead of raw terraform commands
to ensure DNS records are created/cleaned up properly.

## Tasks

Run with `task <name>` from this directory.

- `apply` - Apply terraform and create DNS record
- `destroy` - Full destroy (handles inaccessible clusters gracefully)
- `setup-tfvars` - Create terraform.tfvars with IAM user and SSO role
- `download-model` - Download LLM model from HuggingFace to local models/ directory
- `cleanup` - Clean up resources that block terraform destroy
- `trivy` - Run security scan on Terraform and Docker configs
- `infracost` - Show cost estimate for infrastructure
- `smoke-test` - Run health checks after deployment
- `check` - Run all checks (trivy + infracost)

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_sso_role_name"></a> [admin\_sso\_role\_name](#input\_admin\_sso\_role\_name) | Name of the AWS SSO AdministratorAccess role | `string` | n/a | yes |
| <a name="input_chatbot_replicas"></a> [chatbot\_replicas](#input\_chatbot\_replicas) | Number of chatbot frontend replicas | `number` | `2` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Domain name for the chatbot application | `string` | n/a | yes |
| <a name="input_gpu_node_desired_size"></a> [gpu\_node\_desired\_size](#input\_gpu\_node\_desired\_size) | Desired number of GPU nodes in the EKS cluster | `number` | n/a | yes |
| <a name="input_hosted_zone_name"></a> [hosted\_zone\_name](#input\_hosted\_zone\_name) | Route 53 hosted zone name (e.g., jkim.ai) | `string` | n/a | yes |
| <a name="input_iam_user_name"></a> [iam\_user\_name](#input\_iam\_user\_name) | Name of the IAM user for cluster admin access | `string` | n/a | yes |
| <a name="input_model_id"></a> [model\_id](#input\_model\_id) | HuggingFace model ID (e.g., Qwen/Qwen2.5-1.5B-Instruct) | `string` | `"Qwen/Qwen2.5-1.5B-Instruct"` | no |
| <a name="input_model_s3_prefix"></a> [model\_s3\_prefix](#input\_model\_s3\_prefix) | S3 prefix path to the model files | `string` | `"models"` | no |
| <a name="input_vllm_replicas"></a> [vllm\_replicas](#input\_vllm\_replicas) | Number of vLLM inference server replicas | `number` | `1` | no |

## Outputs

No outputs.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_main"></a> [main](#module\_main) | ./.. | n/a |

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.27.0 |
| <a name="requirement_docker"></a> [docker](#requirement\_docker) | ~> 3.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.17 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.20 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.27.0 |
<!-- END_TF_DOCS -->