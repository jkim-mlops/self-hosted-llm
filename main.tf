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