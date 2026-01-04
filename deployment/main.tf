/**
* # Deployment Configuration
*
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

  cpu_node_desired_size = 1
  gpu_node_desired_size = 0
}