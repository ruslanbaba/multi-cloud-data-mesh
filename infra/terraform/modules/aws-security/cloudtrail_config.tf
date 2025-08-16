terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.35.0"
    }
  }
}

variable "trail_name" { type = string }
variable "log_bucket_name" { type = string }

resource "aws_cloudtrail" "org" {
  name                          = var.trail_name
  s3_bucket_name                = var.log_bucket_name
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
}
