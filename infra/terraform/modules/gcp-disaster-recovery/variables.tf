variable "project_id" {
  description = "GCP project ID"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, start with lowercase letter, contain only lowercase letters, numbers, and hyphens."
  }
}

variable "primary_region" {
  description = "Primary region for resources"
  type        = string
  default     = "us-central1"
  
  validation {
    condition = contains([
      "us-central1", "us-east1", "us-west1", "us-west2",
      "europe-west1", "europe-west2", "europe-west4",
      "asia-east1", "asia-southeast1"
    ], var.primary_region)
    error_message = "Primary region must be a valid GCP region."
  }
}

variable "dr_region" {
  description = "Disaster recovery region"
  type        = string
  default     = "us-east1"
  
  validation {
    condition = contains([
      "us-central1", "us-east1", "us-west1", "us-west2",
      "europe-west1", "europe-west2", "europe-west4", 
      "asia-east1", "asia-southeast1"
    ], var.dr_region)
    error_message = "DR region must be a valid GCP region."
  }
  
  validation {
    condition     = var.dr_region != var.primary_region
    error_message = "DR region must be different from primary region."
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
  description = "List of data domains for disaster recovery"
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

variable "backup_retention_days" {
  description = "Number of days to retain backup data"
  type        = number
  default     = 90
  
  validation {
    condition     = var.backup_retention_days >= 30 && var.backup_retention_days <= 365
    error_message = "Backup retention must be between 30 and 365 days."
  }
}

variable "replication_frequency_hours" {
  description = "Frequency of data replication in hours"
  type        = number
  default     = 6
  
  validation {
    condition     = contains([1, 2, 4, 6, 8, 12, 24], var.replication_frequency_hours)
    error_message = "Replication frequency must be 1, 2, 4, 6, 8, 12, or 24 hours."
  }
}

variable "notification_email" {
  description = "Email for disaster recovery notifications"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "Must be a valid email address."
  }
}

variable "enable_cross_region_backup" {
  description = "Enable cross-region backup"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable disaster recovery monitoring"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Additional labels for resources"
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
