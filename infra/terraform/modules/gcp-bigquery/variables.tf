variable "project_id" {
  description = "GCP project ID"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, start with lowercase letter, contain only lowercase letters, numbers, and hyphens."
  }
}

variable "location" {
  description = "GCP location for BigQuery datasets"
  type        = string
  default     = "US"
  
  validation {
    condition = contains([
      "US", "EU", "us-central1", "us-east1", "us-west1", "us-west2",
      "europe-west1", "europe-west2", "europe-west4",
      "asia-east1", "asia-southeast1"
    ], var.location)
    error_message = "Location must be a valid BigQuery location."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "domains" {
  description = "List of data domains"
  type        = list(string)
  default     = ["clinical", "research", "operational"]
  
  validation {
    condition     = length(var.domains) > 0 && length(var.domains) <= 20
    error_message = "Domains list must contain 1-20 items."
  }
  
  validation {
    condition = alltrue([
      for domain in var.domains : can(regex("^[a-z][a-z0-9-]{1,62}[a-z0-9]$", domain))
    ])
    error_message = "Each domain must be 3-64 characters, start with lowercase letter, contain only lowercase letters, numbers, and hyphens."
  }
}

variable "kms_key_name" {
  description = "KMS key name for encryption"
  type        = string
  
  validation {
    condition     = can(regex("^projects/.+/locations/.+/keyRings/.+/cryptoKeys/.+$", var.kms_key_name))
    error_message = "KMS key name must be in format: projects/PROJECT_ID/locations/LOCATION/keyRings/RING_ID/cryptoKeys/KEY_ID"
  }
}

variable "aws_role_arn" {
  description = "AWS IAM role ARN for BigQuery connections"
  type        = string
  
  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", var.aws_role_arn))
    error_message = "AWS role ARN must be in format: arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME"
  }
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
  
  validation {
    condition = alltrue([
      for k, v in var.labels : can(regex("^[a-z][a-z0-9_-]{0,62}$", k))
    ])
    error_message = "Label keys must be lowercase, start with letter, max 63 chars."
  }
  
  validation {
    condition = alltrue([
      for k, v in var.labels : can(regex("^[a-z0-9_-]{0,63}$", v))
    ])
    error_message = "Label values must be lowercase, max 63 chars."
  }
}
