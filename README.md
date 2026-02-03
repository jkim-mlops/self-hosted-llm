# self-hosted-llm
Example of deploying an LLM on EKS.

<!-- BEGIN_TF_DOCS -->
# Self-Hosted LLM Infrastructure

Terraform module for deploying a self-hosted LLM chatbot on AWS EKS with:
- VPC with public/private subnets
- EKS cluster with CPU and GPU node groups
- vLLM inference server with GPU support
- Streamlit chatbot frontend
- ALB ingress with HTTPS and custom domain
- S3 bucket for model storage with IRSA

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_users"></a> [admin\_users](#input\_admin\_users) | List of IAM user/role ARNs for cluster admin access | `list(string)` | n/a | yes |
| <a name="input_chatbot_replicas"></a> [chatbot\_replicas](#input\_chatbot\_replicas) | Number of chatbot frontend replicas | `number` | `1` | no |
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | CIDR block for VPC | `string` | n/a | yes |
| <a name="input_cpu_node_desired_size"></a> [cpu\_node\_desired\_size](#input\_cpu\_node\_desired\_size) | Desired number of CPU nodes | `number` | n/a | yes |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Domain name for the chatbot application (e.g., chatbot.dev.jkim.ai) | `string` | n/a | yes |
| <a name="input_gpu_node_desired_size"></a> [gpu\_node\_desired\_size](#input\_gpu\_node\_desired\_size) | Desired number of GPU nodes | `number` | n/a | yes |
| <a name="input_hosted_zone_name"></a> [hosted\_zone\_name](#input\_hosted\_zone\_name) | Route 53 hosted zone name (e.g., jkim.ai) | `string` | n/a | yes |
| <a name="input_model_id"></a> [model\_id](#input\_model\_id) | HuggingFace model ID (e.g., Qwen/Qwen2.5-1.5B-Instruct) | `string` | `"Qwen/Qwen2.5-1.5B-Instruct"` | no |
| <a name="input_model_s3_prefix"></a> [model\_s3\_prefix](#input\_model\_s3\_prefix) | S3 prefix path to the model files | `string` | `"models"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for resources | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region | `string` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Map of subnet configurations | <pre>map(object({<br/>    availability_zone = string<br/>    cidr_block        = string<br/>    public            = bool<br/>  }))</pre> | n/a | yes |
| <a name="input_vllm_replicas"></a> [vllm\_replicas](#input\_vllm\_replicas) | Number of vLLM inference server replicas | `number` | `1` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_acm_certificate_arn"></a> [acm\_certificate\_arn](#output\_acm\_certificate\_arn) | ARN of the ACM certificate for HTTPS |
| <a name="output_alb_security_group_id"></a> [alb\_security\_group\_id](#output\_alb\_security\_group\_id) | Security group ID for the Application Load Balancer |
| <a name="output_aws_load_balancer_controller_role_arn"></a> [aws\_load\_balancer\_controller\_role\_arn](#output\_aws\_load\_balancer\_controller\_role\_arn) | IAM role ARN for the AWS Load Balancer Controller |
| <a name="output_chatbot_image_url"></a> [chatbot\_image\_url](#output\_chatbot\_image\_url) | ECR repository URL for the chatbot image (with digest) |
| <a name="output_eks_cluster_ca_certificate"></a> [eks\_cluster\_ca\_certificate](#output\_eks\_cluster\_ca\_certificate) | Base64-encoded CA certificate for cluster authentication |
| <a name="output_eks_cluster_endpoint"></a> [eks\_cluster\_endpoint](#output\_eks\_cluster\_endpoint) | API endpoint for the EKS cluster |
| <a name="output_eks_cluster_name"></a> [eks\_cluster\_name](#output\_eks\_cluster\_name) | Name of the EKS cluster |
| <a name="output_eks_cluster_oidc_issuer"></a> [eks\_cluster\_oidc\_issuer](#output\_eks\_cluster\_oidc\_issuer) | OIDC issuer URL for IAM Roles for Service Accounts (IRSA) |
| <a name="output_model_bucket_arn"></a> [model\_bucket\_arn](#output\_model\_bucket\_arn) | S3 bucket ARN for LLM model storage |
| <a name="output_model_bucket_name"></a> [model\_bucket\_name](#output\_model\_bucket\_name) | S3 bucket name for LLM model storage |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the OIDC provider for IRSA |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | List of public subnet IDs for ALB placement |
| <a name="output_route53_zone_id"></a> [route53\_zone\_id](#output\_route53\_zone\_id) | Route 53 hosted zone ID |
| <a name="output_vllm_role_arn"></a> [vllm\_role\_arn](#output\_vllm\_role\_arn) | IAM role ARN for vLLM pods |
| <a name="output_vllm_server_image_url"></a> [vllm\_server\_image\_url](#output\_vllm\_server\_image\_url) | ECR repository URL for the vLLM server image (with digest) |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_chatbot"></a> [chatbot](#module\_chatbot) | git@github.com:jkim-mlops/terraform-modules.git//modules/docker | 0.2.0 |
| <a name="module_eks"></a> [eks](#module\_eks) | git@github.com:jkim-mlops/terraform-modules.git//modules/eks | feat/eks |
| <a name="module_vllm-server"></a> [vllm-server](#module\_vllm-server) | git@github.com:jkim-mlops/terraform-modules.git//modules/docker | 0.2.0 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | git@github.com:jkim-mlops/terraform-modules.git//modules/vpc | 0.2.0 |

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.27.0 |
| <a name="requirement_docker"></a> [docker](#requirement\_docker) | ~> 3.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.12 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.20 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.27.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 2.12 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 2.20 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
| <a name="provider_tls"></a> [tls](#provider\_tls) | ~> 4.0 |
<!-- END_TF_DOCS -->