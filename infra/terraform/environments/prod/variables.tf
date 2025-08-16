variable "gcp_project_id" {
  description = "GCP Project ID for the data mesh"
  type        = string
}

variable "gcp_region" {
  description = "Primary GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "gcp_dr_region" {
  description = "Secondary GCP region for disaster recovery"
  type        = string
  default     = "us-east1"
}

variable "gcp_billing_account_id" {
  description = "GCP billing account ID for cost management"
  type        = string
}

variable "aws_region" {
  description = "AWS region for S3 ingestion layer"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "multi-cloud-data-mesh"
}

variable "clinical_domains" {
  description = "List of clinical domains for federated data mesh"
  type        = list(string)
  default = [
    "patient_demographics",
    "clinical_notes", 
    "lab_results",
    "medications",
    "allergies",
    "immunizations",
    "vital_signs",
    "procedures",
    "diagnoses",
    "encounters",
    "imaging",
    "genomics",
    "claims",
    "billing",
    "appointments",
    "insurance",
    "provider_data",
    "quality_measures",
    "outcomes",
    "research"
  ]
}

variable "enable_advanced_features" {
  description = "Enable advanced enterprise features (streaming, MLOps, etc.)"
  type        = bool
  default     = true
}

variable "enable_disaster_recovery" {
  description = "Enable multi-region disaster recovery"
  type        = bool
  default     = true
}

variable "enable_cost_optimization" {
  description = "Enable intelligent cost optimization features"
  type        = bool
  default     = true
}

variable "enable_advanced_security" {
  description = "Enable advanced security monitoring and compliance"
  type        = bool
  default     = true
}

variable "bigquery_slot_commitment" {
  description = "BigQuery slot commitment for cost optimization"
  type        = number
  default     = 2000
}

variable "streaming_max_workers" {
  description = "Maximum workers for streaming Dataflow jobs"
  type        = number
  default     = 10
}

variable "ml_notebook_machine_type" {
  description = "Machine type for ML development notebooks"
  type        = string
  default     = "n1-standard-8"
}

variable "backup_retention_days" {
  description = "Data backup retention period in days"
  type        = number
  default     = 2555  # 7 years for HIPAA compliance
}

variable "monitoring_notification_email" {
  description = "Email for monitoring alerts and notifications"
  type        = string
  default     = "data-ops@example.com"
}

variable "cost_alert_threshold_usd" {
  description = "Monthly cost alert threshold in USD"
  type        = number
  default     = 50000
}

variable "enable_audit_logging" {
  description = "Enable comprehensive audit logging across all services"
  type        = bool
  default     = true
}

variable "data_retention_policy" {
  description = "Data retention policy configuration"
  type = object({
    hot_data_days     = number
    warm_data_days    = number
    cold_data_days    = number
    archive_data_days = number
  })
  default = {
    hot_data_days     = 90
    warm_data_days    = 365
    cold_data_days    = 1825  # 5 years
    archive_data_days = 2555  # 7 years
  }
}

variable "compliance_requirements" {
  description = "Compliance requirements for the data mesh"
  type = object({
    hipaa_enabled     = bool
    sox_enabled       = bool
    gdpr_enabled      = bool
    ccpa_enabled      = bool
  })
  default = {
    hipaa_enabled = true
    sox_enabled   = true
    gdpr_enabled  = true
    ccpa_enabled  = true
  }
}

variable "network_security" {
  description = "Network security configuration"
  type = object({
    enable_private_google_access = bool
    enable_vpc_service_controls  = bool
    allowed_ip_ranges           = list(string)
  })
  default = {
    enable_private_google_access = true
    enable_vpc_service_controls  = true
    allowed_ip_ranges           = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }
}
