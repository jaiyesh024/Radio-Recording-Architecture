# IRSA: lets the recorder pods write to S3 without embedding AWS credentials.
# A Kubernetes ServiceAccount is annotated with this role's ARN; the EKS OIDC
# provider (created by the eks module with enable_irsa = true) lets pods using
# that ServiceAccount assume it.

data "aws_iam_policy_document" "recorder_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:sub"
      values   = ["system:serviceaccount:radio-recorders:recorder"]           # Only the recorder ServiceAccount in the radio-recorders namespace can assume this role.
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]                          # restrict the token audience to STS
    }
  }
}

resource "aws_iam_role" "recorder" {
  name               = "${var.cluster_name}-recorder"
  assume_role_policy = data.aws_iam_policy_document.recorder_assume_role.json
}

data "aws_iam_policy_document" "recorder_s3_access" {
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
    ]
    resources = ["${aws_s3_bucket.recordings.arn}/recordings/*"]       #object ARN
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.recordings.arn]              # bucket ARN
  }
}

resource "aws_iam_policy" "recorder_s3_access" {
  name   = "${var.cluster_name}-recorder-s3-access"
  policy = data.aws_iam_policy_document.recorder_s3_access.json
}

resource "aws_iam_role_policy_attachment" "recorder_s3_access" {
  role       = aws_iam_role.recorder.name
  policy_arn = aws_iam_policy.recorder_s3_access.arn
}

resource "kubernetes_namespace" "radio_recorders" {
  metadata {
    name = "radio-recorders"
  }
}

resource "kubernetes_service_account" "recorder" {
  metadata {
    name      = "recorder"
    namespace = kubernetes_namespace.radio_recorders.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.recorder.arn
    }
  }
}
