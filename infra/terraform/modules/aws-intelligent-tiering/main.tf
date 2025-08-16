terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.45.0"
    }
  }
}

variable "environment" { type = string }
variable "domains" { type = list(string) }
variable "s3_bucket_name" { type = string }
variable "kms_key_id" { type = string }

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# S3 Intelligent Tiering configurations
resource "aws_s3_bucket_intelligent_tiering_configuration" "domain_tiering" {
  for_each = toset(var.domains)
  
  bucket = var.s3_bucket_name
  name   = "${each.key}-intelligent-tiering"
  
  filter {
    prefix = "${each.key}/"
    
    tags = {
      Domain      = each.key
      Environment = var.environment
      DataClass   = "phi"
    }
  }
  
  tiering {
    access_tier = "ARCHIVE_ACCESS"
  }
  
  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
  }
  
  optional_fields = ["BucketKeyStatus", "ChecksumAlgorithm"]
  
  status = "Enabled"
}

# S3 Storage Class Analysis for optimization insights
resource "aws_s3_bucket_analytics_configuration" "storage_analytics" {
  for_each = toset(var.domains)
  
  bucket = var.s3_bucket_name
  name   = "${each.key}-storage-analytics"
  
  filter {
    prefix = "${each.key}/"
    
    tags = {
      Domain = each.key
    }
  }
  
  storage_class_analysis {
    data_export {
      destination {
        s3_bucket_destination {
          bucket_arn = aws_s3_bucket.analytics_reports.arn
          prefix     = "storage-analytics/${each.key}/"
          format     = "CSV"
        }
      }
      
      output_schema_version = "V_1"
    }
  }
}

# S3 bucket for analytics reports
resource "aws_s3_bucket" "analytics_reports" {
  bucket = "${var.s3_bucket_name}-analytics-${var.environment}"
  
  tags = {
    Environment = var.environment
    Purpose     = "storage-analytics"
  }
}

resource "aws_s3_bucket_versioning" "analytics_versioning" {
  bucket = aws_s3_bucket.analytics_reports.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "analytics_encryption" {
  bucket = aws_s3_bucket.analytics_reports.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_id
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "analytics_lifecycle" {
  bucket = aws_s3_bucket.analytics_reports.id
  
  rule {
    id     = "analytics-lifecycle"
    status = "Enabled"
    
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }
    
    expiration {
      days = 2555 # 7 years for compliance
    }
  }
}

# CloudWatch metrics for storage optimization
resource "aws_cloudwatch_log_group" "storage_optimization" {
  name              = "/aws/s3/storage-optimization-${var.environment}"
  retention_in_days = 30
  kms_key_id       = var.kms_key_id
  
  tags = {
    Environment = var.environment
    Purpose     = "storage-optimization"
  }
}

# Lambda function for cost optimization analysis
resource "aws_lambda_function" "cost_analyzer" {
  filename         = "cost-analyzer.zip"
  function_name    = "s3-cost-analyzer-${var.environment}"
  role            = aws_iam_role.cost_analyzer.arn
  handler         = "index.handler"
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 512
  
  environment {
    variables = {
      ENVIRONMENT    = var.environment
      S3_BUCKET     = var.s3_bucket_name
      ANALYTICS_BUCKET = aws_s3_bucket.analytics_reports.bucket
    }
  }
  
  kms_key_arn = var.kms_key_id
  
  tags = {
    Environment = var.environment
    Purpose     = "cost-optimization"
  }
}

resource "aws_iam_role" "cost_analyzer" {
  name = "s3-cost-analyzer-${var.environment}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "cost_analyzer_policy" {
  name = "s3-cost-analyzer-policy-${var.environment}"
  role = aws_iam_role.cost_analyzer.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetStorageClassAnalysis",
          "s3:GetIntelligentTieringConfiguration",
          "s3:PutIntelligentTieringConfiguration"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*",
          aws_s3_bucket.analytics_reports.arn,
          "${aws_s3_bucket.analytics_reports.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# EventBridge rule for scheduled optimization
resource "aws_cloudwatch_event_rule" "cost_optimization_schedule" {
  name                = "s3-cost-optimization-${var.environment}"
  description         = "Trigger S3 cost optimization analysis"
  schedule_expression = "cron(0 2 * * ? *)" # Daily at 2 AM UTC
  
  tags = {
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.cost_optimization_schedule.name
  target_id = "CostAnalyzerTarget"
  arn       = aws_lambda_function.cost_analyzer.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_analyzer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cost_optimization_schedule.arn
}

# Cost and Usage Reports
resource "aws_cur_report_definition" "data_mesh_usage" {
  report_name         = "data-mesh-usage-${var.environment}"
  time_unit           = "DAILY"
  format              = "Parquet"
  compression         = "GZIP"
  additional_schema_elements = ["RESOURCES"]
  s3_bucket           = aws_s3_bucket.cost_reports.bucket
  s3_prefix           = "cost-reports/"
  s3_region           = data.aws_region.current.name
  additional_artifacts = ["ATHENA", "QUICKSIGHT"]
  refresh_closed_reports = true
  report_versioning = "OVERWRITE_REPORT"
}

resource "aws_s3_bucket" "cost_reports" {
  bucket = "${var.s3_bucket_name}-cost-reports-${var.environment}"
  
  tags = {
    Environment = var.environment
    Purpose     = "cost-reports"
  }
}

resource "aws_s3_bucket_policy" "cost_reports_policy" {
  bucket = aws_s3_bucket.cost_reports.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "billingreports.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cost_reports.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketExistenceCheck"
        Effect = "Allow"
        Principal = {
          Service = "billingreports.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.cost_reports.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "billingreports.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cost_reports.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# CloudWatch Alarms for cost monitoring
resource "aws_cloudwatch_metric_alarm" "s3_cost_alarm" {
  alarm_name          = "s3-cost-alarm-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400" # 24 hours
  statistic           = "Maximum"
  threshold           = var.environment == "prod" ? "1000" : "200"
  alarm_description   = "This metric monitors S3 costs"
  alarm_actions       = [aws_sns_topic.cost_alerts.arn]
  
  dimensions = {
    Currency    = "USD"
    ServiceName = "AmazonS3"
  }
  
  tags = {
    Environment = var.environment
  }
}

resource "aws_sns_topic" "cost_alerts" {
  name              = "s3-cost-alerts-${var.environment}"
  kms_master_key_id = var.kms_key_id
  
  tags = {
    Environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "cost_alerts_email" {
  topic_arn = aws_sns_topic.cost_alerts.arn
  protocol  = "email"
  endpoint  = "cost-alerts@example.com"
}

output "intelligent_tiering_configs" {
  value = { for k, config in aws_s3_bucket_intelligent_tiering_configuration.domain_tiering : k => config.name }
}

output "analytics_bucket" {
  value = aws_s3_bucket.analytics_reports.bucket
}

output "cost_reports_bucket" {
  value = aws_s3_bucket.cost_reports.bucket
}

output "cost_analyzer_function" {
  value = aws_lambda_function.cost_analyzer.function_name
}
