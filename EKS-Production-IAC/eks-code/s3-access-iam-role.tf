###
# S3 access for product-service, via IRSA - reuses the SAME OIDC provider
# already created in alb-controller-iam.tf (aws_iam_openid_connect_provider.eks_oidc).
# Do NOT create a second OIDC provider resource - a cluster can only have
# one registered per issuer URL, and trying to create a duplicate will fail.


data "aws_iam_policy_document" "product_service_s3_access" {
  # Scoped to ONLY this bucket's media/ prefix (matches AWS_LOCATION =
  # "media" in productservice/settings.py) - not blanket S3 access.
  statement {
    sid       = "ListBucketMediaPrefixOnly"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.bucket_name}"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["media/*"]
    }
  }

  statement {
    sid       = "ReadWriteMediaObjectsOnly"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/media/*"]
  }
}

resource "aws_iam_policy" "product_service_s3_access" {
  name        = "${var.name_prefix}-product-service-s3-media"
  description = "Least-privilege S3 access for product-service (media/ prefix only)"
  policy      = data.aws_iam_policy_document.product_service_s3_access.json
  tags        = local.common_tags
}

###
# Trust policy: ONLY the product-service-sa ServiceAccount, in the shopflow
# namespace, on THIS cluster's EXISTING OIDC provider, can assume this role.
data "aws_iam_policy_document" "product_service_trust" {
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
      values   = ["system:serviceaccount:shopflow:product-service-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "product_service" {
  name               = "${var.name_prefix}-product-service-role"
  assume_role_policy = data.aws_iam_policy_document.product_service_trust.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "product_service_s3" {
  role       = aws_iam_role.product_service.name
  policy_arn = aws_iam_policy.product_service_s3_access.arn
}


