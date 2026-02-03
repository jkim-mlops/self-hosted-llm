# -----------------------------------------------------------------------------
# IAM Policy for AWS Load Balancer Controller
# -----------------------------------------------------------------------------
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${var.name}-AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller to manage ALB/NLB resources"
  policy      = file("${path.module}/policies/aws-load-balancer-controller-policy.json")

  tags = {
    Name = "${var.name}-alb-controller-policy"
  }
}

# -----------------------------------------------------------------------------
# IAM Role for AWS Load Balancer Controller (IRSA)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "aws_load_balancer_controller" {
  name        = "${var.name}-aws-load-balancer-controller"
  description = "IAM role for AWS Load Balancer Controller using IRSA"

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
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Name = "${var.name}-alb-controller-role"
  }
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
  role       = aws_iam_role.aws_load_balancer_controller.name
}
