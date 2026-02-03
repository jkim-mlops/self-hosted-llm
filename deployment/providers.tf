provider "aws" {}

data "aws_ecr_authorization_token" "this" {}

provider "docker" {
  registry_auth {
    address  = data.aws_ecr_authorization_token.this.proxy_endpoint
    username = data.aws_ecr_authorization_token.this.user_name
    password = data.aws_ecr_authorization_token.this.password
  }
}

# -----------------------------------------------------------------------------
# Kubernetes Provider Configuration
# -----------------------------------------------------------------------------
data "aws_eks_cluster_auth" "this" {
  name = module.main.eks_cluster_name
}

provider "kubernetes" {
  host                   = module.main.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.main.eks_cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.this.token
}

# -----------------------------------------------------------------------------
# Helm Provider Configuration
# -----------------------------------------------------------------------------
provider "helm" {
  kubernetes {
    host                   = module.main.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.main.eks_cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}