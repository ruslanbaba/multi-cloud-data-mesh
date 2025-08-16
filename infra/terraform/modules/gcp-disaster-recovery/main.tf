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
variable "primary_region" { type = string }
variable "dr_region" { type = string }
variable "environment" { type = string }
variable "domains" { type = list(string) }
variable "kms_key_name" { type = string }

# Cross-region BigQuery dataset replication
resource "google_bigquery_dataset" "dr_datasets" {
  for_each   = toset(var.domains)
  project    = var.project_id
  dataset_id = "${replace(each.key, "-", "_")}_${var.environment}_dr"
  location   = var.dr_region
  
  default_encryption_configuration { 
    kms_key_name = var.kms_key_name 
  }
  
  labels = {
    environment = var.environment
    domain      = each.key
    dataclass   = "phi"
    purpose     = "disaster-recovery"
  }
}

# Scheduled BigQuery data transfer for DR
resource "google_bigquery_data_transfer_config" "cross_region_transfer" {
  for_each = toset(var.domains)
  
  display_name           = "DR-Transfer-${each.key}"
  location              = var.dr_region
  data_source_id        = "scheduled_query"
  schedule              = "every 6 hours"
  destination_dataset_id = google_bigquery_dataset.dr_datasets[each.key].dataset_id
  
  params = {
    query = <<-EOT
      CREATE OR REPLACE TABLE `${var.project_id}.${google_bigquery_dataset.dr_datasets[each.key].dataset_id}.${each.key}_replicated` AS 
      SELECT * FROM `${var.project_id}.${each.key}_${var.environment}.${each.key}_external`
      WHERE _PARTITIONTIME >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
    EOT
    destination_table_name_template = "${each.key}_replicated"
    write_disposition = "WRITE_TRUNCATE"
  }
}

# Cloud Storage buckets for cross-region backup
resource "google_storage_bucket" "dr_backup" {
  name     = "${var.project_id}-dr-backup-${var.environment}"
  location = var.dr_region
  
  uniform_bucket_level_access = true
  
  versioning {
    enabled = true
  }
  
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }
  
  encryption {
    default_kms_key_name = var.kms_key_name
  }
}

# Backup job for critical configuration
resource "google_cloud_scheduler_job" "dr_backup" {
  name             = "dr-backup-${var.environment}"
  description      = "Backup critical data mesh configurations"
  schedule         = "0 2 * * *"
  time_zone        = "UTC"
  region           = var.primary_region
  
  http_target {
    http_method = "POST"
    uri         = "https://cloudfunctions.googleapis.com/v1/projects/${var.project_id}/locations/${var.primary_region}/functions/dr-backup-function:call"
    
    oidc_token {
      service_account_email = google_service_account.dr_backup.email
    }
  }
}

resource "google_service_account" "dr_backup" {
  account_id   = "dr-backup-sa-${var.environment}"
  display_name = "Disaster Recovery Backup Service Account"
}

resource "google_project_iam_member" "dr_backup_permissions" {
  for_each = toset([
    "roles/bigquery.dataViewer",
    "roles/storage.objectAdmin",
    "roles/composer.worker"
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.dr_backup.email}"
}

# Health check for DR readiness
resource "google_monitoring_uptime_check_config" "dr_readiness" {
  display_name = "DR Readiness Check"
  timeout      = "10s"
  period       = "300s"
  
  http_check {
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"
    path           = "/health"
  }
  
  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = "${var.project_id}.cloudfunctions.net"
    }
  }
  
  content_matchers {
    content = "DR_READY"
    matcher = "CONTAINS_STRING"
  }
}

output "dr_datasets" {
  value = { for k, d in google_bigquery_dataset.dr_datasets : k => d.dataset_id }
}
output "dr_backup_bucket" { value = google_storage_bucket.dr_backup.name }
