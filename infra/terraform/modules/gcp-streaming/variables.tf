variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for streaming resources"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "domains" {
  description = "List of clinical domains for streaming"
  type        = list(string)
  default = [
    "patient_demographics", "clinical_notes", "lab_results", "medications",
    "allergies", "immunizations", "vital_signs", "procedures", "diagnoses",
    "encounters", "imaging", "genomics", "claims", "billing", "appointments",
    "insurance", "provider_data", "quality_measures", "outcomes", "research"
  ]
}

variable "network" {
  description = "VPC network for Dataflow jobs"
  type        = string
}

variable "subnetwork" {
  description = "VPC subnetwork for Dataflow jobs"
  type        = string
}

variable "max_workers" {
  description = "Maximum number of Dataflow workers"
  type        = number
  default     = 5
}

variable "machine_type" {
  description = "Machine type for Dataflow workers"
  type        = string
  default     = "n1-standard-2"
}

variable "enable_streaming_engine" {
  description = "Enable Dataflow Streaming Engine"
  type        = bool
  default     = true
}

variable "message_retention_hours" {
  description = "Message retention in hours for Pub/Sub topics"
  type        = number
  default     = 24
}

variable "partition_retention_days" {
  description = "Partition retention in days for streaming tables"
  type        = number
  default     = 30
}

variable "enable_dlq" {
  description = "Enable dead letter queue for failed messages"
  type        = bool
  default     = true
}

variable "max_delivery_attempts" {
  description = "Maximum delivery attempts before sending to DLQ"
  type        = number
  default     = 5
}
