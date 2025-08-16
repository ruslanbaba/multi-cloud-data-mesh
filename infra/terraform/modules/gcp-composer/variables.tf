variable "project_id" {
  description = "GCP project ID"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, start with lowercase letter, contain only lowercase letters, numbers, and hyphens."
  }
}

variable "location" {
  description = "GCP location for Composer environment"
  type        = string
  default     = "us-central1"
  
  validation {
    condition = contains([
      "us-central1", "us-east1", "us-west1", "us-west2",
      "europe-west1", "europe-west2", "europe-west4",
      "asia-east1", "asia-southeast1"
    ], var.location)
    error_message = "Location must be a valid GCP region."
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

variable "composer_image_version" {
  description = "Cloud Composer image version"
  type        = string
  default     = "composer-2-airflow-2"
  
  validation {
    condition     = can(regex("^composer-[0-9]+-airflow-[0-9]+", var.composer_image_version))
    error_message = "Composer image version must be in format: composer-X-airflow-Y"
  }
}

variable "composer_service_account" {
  description = "Service account email for Composer"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.composer_service_account))
    error_message = "Must be a valid service account email address."
  }
}

variable "vpc_network" {
  description = "VPC network self-link"
  type        = string
  
  validation {
    condition     = can(regex("^projects/.+/global/networks/.+$", var.vpc_network))
    error_message = "VPC network must be in format: projects/PROJECT_ID/global/networks/NETWORK_NAME"
  }
}

variable "vpc_subnetwork" {
  description = "VPC subnetwork self-link"
  type        = string
  
  validation {
    condition     = can(regex("^projects/.+/regions/.+/subnetworks/.+$", var.vpc_subnetwork))
    error_message = "VPC subnetwork must be in format: projects/PROJECT_ID/regions/REGION/subnetworks/SUBNET_NAME"
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

variable "enable_private_ip" {
  description = "Enable private IP for Composer environment"
  type        = bool
  default     = true
}

variable "node_count" {
  description = "Number of nodes in the Composer environment"
  type        = number
  default     = 3
  
  validation {
    condition     = var.node_count >= 3 && var.node_count <= 10
    error_message = "Node count must be between 3 and 10."
  }
}

variable "machine_type" {
  description = "Machine type for Composer nodes"
  type        = string
  default     = "n1-standard-1"
  
  validation {
    condition = contains([
      "n1-standard-1", "n1-standard-2", "n1-standard-4",
      "n2-standard-2", "n2-standard-4", "n2-standard-8"
    ], var.machine_type)
    error_message = "Machine type must be a valid GCP machine type."
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
