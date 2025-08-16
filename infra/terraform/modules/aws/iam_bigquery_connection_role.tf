# IAM role to be assumed by GCP BigQuery Connection (AWS external connection)
# Trust policy will be updated with the AWS IAM Identity Center or a specific principal used by GCP connection.

variable "bigquery_connection_principal_arn" {
  description = "AWS principal that GCP BigQuery Connection will assume (provided via OIDC/SRAM bridging)."
  type        = string
}

resource "aws_iam_role" "bigquery_connection" {
  name               = "bq-conn-cross-acct-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "trust" {
  statement {
    sid    = "TrustBigQueryConnection"
    effect = "Allow"
    principals { type = "AWS" identifiers = [var.bigquery_connection_principal_arn] }
    actions = ["sts:AssumeRole"]
  }
}

# Least privilege read-only to domain buckets
resource "aws_iam_policy" "read_domain_buckets" {
  name        = "bq-conn-readonly-${var.environment}"
  description = "Read-only access from BigQuery connection to S3 domain buckets"
  policy      = data.aws_iam_policy_document.read.json
}

data "aws_iam_policy_document" "read" {
  statement {
    sid       = "ListBuckets"
    actions   = ["s3:ListAllMyBuckets", "s3:GetBucketLocation"]
    resources = ["*"]
  }
  statement {
    sid = "ReadObjects"
    actions = ["s3:GetObject", "s3:GetObjectVersion", "s3:ListBucket"]
    resources = flatten([
      for b in aws_s3_bucket.domain : [
        b.arn,
        "${b.arn}/*"
      ]
    ])
  }
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.bigquery_connection.name
  policy_arn = aws_iam_policy.read_domain_buckets.arn
}

output "bigquery_connection_role_arn" {
  value = aws_iam_role.bigquery_connection.arn
}
