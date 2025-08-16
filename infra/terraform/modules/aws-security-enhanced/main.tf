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
variable "s3_bucket_names" { type = list(string) }
variable "kms_key_arn" { type = string }

# GuardDuty for threat detection
resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  
  datasources {
    s3_logs { enable = true }
    kubernetes { audit_logs { enable = true } }
    malware_protection { scan_ec2_instance_with_findings { ebs_volumes { enable = true } } }
  }
  
  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# Security Hub for centralized security findings
resource "aws_securityhub_account" "main" {
  enable_default_standards = true
}

# Macie for sensitive data discovery
resource "aws_macie2_account" "main" {
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  status                       = "ENABLED"
}

resource "aws_macie2_classification_job" "s3_phi_scan" {
  for_each = toset(var.s3_bucket_names)
  
  job_type = "SCHEDULED"
  name     = "phi-scan-${each.value}"
  
  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets    = [each.value]
    }
  }
  
  schedule_frequency {
    daily_schedule = true
  }
  
  tags = {
    Project     = var.project
    Environment = var.environment
    Purpose     = "PHI-Detection"
  }
}

# Config for compliance monitoring
resource "aws_config_configuration_recorder" "main" {
  name     = "data-mesh-recorder-${var.environment}"
  role_arn = aws_iam_role.config.arn
  
  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "data-mesh-delivery-${var.environment}"
  s3_bucket_name = aws_s3_bucket.config.bucket
  s3_key_prefix  = "config"
}

resource "aws_s3_bucket" "config" {
  bucket        = "${var.project}-config-${var.environment}-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

resource "aws_iam_role" "config" {
  name = "config-role-${var.environment}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "config.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

# Custom Config rules for HIPAA compliance
resource "aws_config_config_rule" "s3_bucket_public_access_prohibited" {
  name = "s3-bucket-public-access-prohibited"
  
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_ACCESS_PROHIBITED"
  }
  
  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "encrypted_volumes" {
  name = "encrypted-volumes"
  
  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }
  
  depends_on = [aws_config_configuration_recorder.main]
}

data "aws_caller_identity" "current" {}
resource "random_id" "suffix" { byte_length = 4 }

output "guardduty_detector_id" { value = aws_guardduty_detector.main.id }
output "security_hub_arn" { value = aws_securityhub_account.main.arn }
output "macie_account_id" { value = aws_macie2_account.main.id }
