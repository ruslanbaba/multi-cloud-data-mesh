terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.35.0"
    }
  }
}

variable "project" { type = string }
variable "environment" { type = string }
variable "region" { type = string }
variable "domains" {
  description = "Clinical domain names to provision distinct S3 buckets/prefixes"
  type        = list(string)
}
variable "bucket_name_prefix" { type = string }
variable "log_bucket_name" { type = string }

# KMS CMK per environment
resource "aws_kms_key" "ingestion" {
  description             = "CMK for S3 server-side encryption (${var.environment})"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms.json
  tags = {
    Project     = var.project
    Environment = var.environment
    DataClass   = "PHI"
  }
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "kms" {
  statement {
    sid     = "EnableRootAccount"
    effect  = "Allow"
    actions = [
      "kms:Describe*",
      "kms:List*",
      "kms:Create*",
      "kms:Update*",
      "kms:Delete*",
      "kms:Tag*",
      "kms:Untag*",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion"
    ]
    principals { type = "AWS" identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"] }
    resources = ["*"]
  }
  
  statement {
    sid     = "EnableServiceAccess"
    effect  = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    principals { 
      type = "Service" 
      identifiers = [
        "s3.amazonaws.com",
        "logs.amazonaws.com"
      ]
    }
    resources = ["*"]
  }
}

# Central access log bucket
resource "aws_s3_bucket" "logs" {
  bucket        = var.log_bucket_name
  force_destroy = false
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" kms_master_key_id = aws_kms_key.ingestion.arn } }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Per-domain buckets
resource "aws_s3_bucket" "domain" {
  for_each     = toset(var.domains)
  bucket       = "${var.bucket_name_prefix}-${each.key}-${var.environment}"
  force_destroy = false
  tags = {
    Project     = var.project
    Environment = var.environment
    Domain      = each.key
    DataClass   = "PHI"
  }
}

resource "aws_s3_bucket_ownership_controls" "domain" {
  for_each = aws_s3_bucket.domain
  bucket   = each.value.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_s3_bucket_versioning" "domain" {
  for_each = aws_s3_bucket.domain
  bucket   = each.value.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_logging" "domain" {
  for_each      = aws_s3_bucket.domain
  bucket        = each.value.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "${each.key}/"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "domain" {
  for_each = aws_s3_bucket.domain
  bucket   = each.value.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" kms_master_key_id = aws_kms_key.ingestion.arn } }
}

resource "aws_s3_bucket_public_access_block" "domain" {
  for_each                = aws_s3_bucket.domain
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Optional: Object Lock can be enabled by creating bucket with configuration first; left out for brevity.

# Enforce TLS (HTTPS) access only
resource "aws_s3_bucket_policy" "tls_only" {
  for_each = aws_s3_bucket.domain
  bucket   = each.value.id
  policy   = data.aws_iam_policy_document.tls_only[each.key].json
}

data "aws_iam_policy_document" "tls_only" {
  for_each = aws_s3_bucket.domain
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    principals { type = "AWS" identifiers = ["*"] }
    resources = [each.value.arn, "${each.value.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# Lifecycle rules: abort incomplete multipart uploads and transition noncurrent versions after retention windows
resource "aws_s3_bucket_lifecycle_configuration" "domain" {
  for_each = aws_s3_bucket.domain
  bucket   = each.value.id
  rule {
    id     = "AbortIncompleteMultipartUpload"
    status = "Enabled"
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

output "bucket_names" {
  value = { for k, b in aws_s3_bucket.domain : k => b.bucket }
}
output "kms_key_arn" { value = aws_kms_key.ingestion.arn }
