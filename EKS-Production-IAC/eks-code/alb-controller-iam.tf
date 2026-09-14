data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.prod_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_oidc" {
  url             = aws_eks_cluster.prod_cluster.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-eks-oidc-provider"
  })
}
### 
resource "aws_iam_policy" "alb_controller" {
  name        = "${var.name_prefix}-aws-load-balancer-controller"
  description = "Permissions for the AWS Load Balancer Controller to manage ALBs/NLBs from Ingress/Service resources"
  policy      = file("${path.module}/iam_policy.json")

  tags = local.common_tags
}
####
data "aws_iam_policy_document" "alb_controller_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks_oidc.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}
#####
resource "aws_iam_role" "alb_controller" {
  name               = "${var.name_prefix}-alb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_trust.json

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-alb-controller-role"
  })
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

###
output "alb_controller_role_arn" {
  description = "Paste into the eks.amazonaws.com/role-arn annotation on the aws-load-balancer-controller ServiceAccount (kube-system namespace) before helm-installing the controller"
  value       = aws_iam_role.alb_controller.arn
}

output "eks_oidc_provider_arn" {
  description = "Reuse this for any other IRSA role on this cluster (e.g. product-service's S3 access role) instead of creating a second OIDC provider"
  value       = aws_iam_openid_connect_provider.eks_oidc.arn
}