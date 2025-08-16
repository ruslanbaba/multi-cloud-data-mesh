variable "project_id" { 
  description = "GCP project ID for ML resources"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, lowercase letters, digits, and hyphens only."
  }
}

variable "region" { 
  description = "GCP region for ML resources"
  type        = string
  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.region))
    error_message = "Region must be a valid GCP region format."
  }
}

variable "environment" { 
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "domains" { 
  description = "List of clinical domains for ML processing"
  type        = list(string)
  validation {
    condition     = length(var.domains) > 0 && length(var.domains) <= 50
    error_message = "Domains list must contain 1-50 valid domain names."
  }
}

variable "bigquery_datasets" { 
  description = "Map of BigQuery dataset IDs for ML training"
  type        = map(string)
  sensitive   = false
}

variable "kms_key_id" { 
  description = "KMS key ID for encryption"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("^projects/.+/locations/.+/keyRings/.+/cryptoKeys/.+$", var.kms_key_id))
    error_message = "KMS key ID must be in full resource name format."
  }
}

variable "network_name" {
  description = "VPC network name for secure ML workbench deployment"
  type        = string
  default     = null
}

variable "subnet_name" {
  description = "Subnet name for secure ML workbench deployment"
  type        = string
  default     = null
}

variable "allowed_users" {
  description = "List of authorized users for ML workbench access"
  type        = list(string)
  validation {
    condition     = length(var.allowed_users) > 0
    error_message = "At least one authorized user must be specified."
  }
}

variable "enable_ip_forwarding" {
  description = "Enable IP forwarding on ML workbench (security risk if enabled)"
  type        = bool
  default     = false
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB for ML workbench"
  type        = number
  default     = 100
  validation {
    condition     = var.boot_disk_size_gb >= 20 && var.boot_disk_size_gb <= 1000
    error_message = "Boot disk size must be between 20 and 1000 GB."
  }
}

variable "github_owner" {
  description = "GitHub organization/owner for ML pipeline"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$", var.github_owner))
    error_message = "GitHub owner must be a valid organization name."
  }
}

variable "github_repo" {
  description = "GitHub repository name for ML pipeline"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$", var.github_repo))
    error_message = "GitHub repository must be a valid repository name."
  }
}

variable "secure_worker_pool" {
  description = "Secure worker pool for production Cloud Build jobs"
  type        = string
  default     = null
}

variable "enable_workbench_monitoring" {
  description = "Enable advanced monitoring for ML workbench"
  type        = bool
  default     = true
}

variable "workbench_machine_type" {
  description = "Machine type for ML workbench"
  type        = string
  default     = "n1-standard-4"
  validation {
    condition = contains([
      "n1-standard-1", "n1-standard-2", "n1-standard-4", "n1-standard-8", 
      "n1-standard-16", "n1-highmem-2", "n1-highmem-4", "n1-highmem-8"
    ], var.workbench_machine_type)
    error_message = "Machine type must be a valid GCP machine type."
  }
}

variable "enable_gpu" {
  description = "Enable GPU acceleration for ML workbench"
  type        = bool
  default     = false
}

variable "gpu_type" {
  description = "GPU type for ML workbench"
  type        = string
  default     = "NVIDIA_TESLA_T4"
  validation {
    condition = contains([
      "NVIDIA_TESLA_K80", "NVIDIA_TESLA_P4", "NVIDIA_TESLA_P100",
      "NVIDIA_TESLA_V100", "NVIDIA_TESLA_T4"
    ], var.gpu_type)
    error_message = "GPU type must be a valid NVIDIA GPU type."
  }
}

variable "gpu_count" {
  description = "Number of GPUs for ML workbench"
  type        = number
  default     = 0
  validation {
    condition     = var.gpu_count >= 0 && var.gpu_count <= 8
    error_message = "GPU count must be between 0 and 8."
  }
}

variable "data_disk_size_gb" {
  description = "Data disk size in GB for ML workbench"
  type        = number
  default     = 500
  validation {
    condition     = var.data_disk_size_gb >= 100 && var.data_disk_size_gb <= 10000
    error_message = "Data disk size must be between 100 and 10000 GB."
  }
}

variable "enable_audit_logging" {
  description = "Enable audit logging for ML operations"
  type        = bool
  default     = true
}

variable "notification_email" {
  description = "Email for ML operations notifications"
  type        = string
  default     = ""
  validation {
    condition     = var.notification_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "Notification email must be a valid email address or empty."
  }
}
