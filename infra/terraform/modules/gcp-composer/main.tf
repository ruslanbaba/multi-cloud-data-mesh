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
variable "image_version" { type = string }
variable "composer_service_account" { type = string }
variable "network" { type = string }
variable "subnetwork" { type = string }
variable "kms_key_name" { type = string }

resource "google_composer_environment" "env" {
  project  = var.project_id
  name     = "composer-${var.environment}"
  region   = var.location

  config {
    software_config {
      image_version = var.image_version
      env_variables = { DBT_TARGET = var.environment }
    }
    node_config {
      service_account = var.composer_service_account
      network         = var.network
      subnetwork      = var.subnetwork
    }
    encryption_config { kms_key_name = var.kms_key_name }
  }
}

output "composer_gke_cluster" { value = google_composer_environment.env.config.0.gke_cluster }
