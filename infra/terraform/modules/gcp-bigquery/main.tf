terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.31.1"
    }
  }
}

variable "project_id" { type = string }
variable "location" { type = string }
variable "environment" { type = string }
variable "domains" { type = list(string) }
variable "kms_key_name" { type = string } # full crypto key resource id
variable "aws_role_arn" { type = string }

resource "google_bigquery_dataset" "domain" {
  for_each   = toset(var.domains)
  project    = var.project_id
  dataset_id = "${replace(each.key, "-", "_")}_${var.environment}"
  location   = var.location
  default_encryption_configuration { kms_key_name = var.kms_key_name }
  labels = {
    environment = var.environment
    domain      = each.key
    dataclass   = "phi"
  }
}

resource "google_bigquery_connection" "aws" {
  project         = var.project_id
  location        = var.location
  connection_id   = "aws_s3_${var.environment}"
  connection_type = "AWS"
  aws { role_arn = var.aws_role_arn }
}

output "datasets" {
  value = { for k, d in google_bigquery_dataset.domain : k => d.dataset_id }
}
output "connection_id" { value = google_bigquery_connection.aws.id }
