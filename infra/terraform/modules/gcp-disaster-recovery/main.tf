terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.31.1"
    }
  }
}

# Cross-region BigQuery dataset replication
resource "google_bigquery_dataset" "dr_datasets" {
  for_each   = toset(var.domains)
  project    = var.project_id
  dataset_id = "${replace(each.key, "-", "_")}_${var.environment}_dr"
  location   = var.dr_region
  
  default_encryption_configuration { 
    kms_key_name = var.kms_key_name 
  }
  
  labels = merge(var.labels, {
    environment = var.environment
    domain      = each.key
    dataclass   = "phi"
    purpose     = "disaster-recovery"
  })
}

# Scheduled BigQuery data transfer for DR
resource "google_bigquery_data_transfer_config" "cross_region_transfer" {
  for_each = toset(var.domains)
  
  display_name           = "DR-Transfer-${each.key}"
  location              = var.dr_region
  data_source_id        = "scheduled_query"
  schedule              = "every ${var.replication_frequency_hours} hours"
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
  count    = var.enable_cross_region_backup ? 1 : 0
  name     = "${var.project_id}-dr-backup-${var.environment}"
  location = var.dr_region
  
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  
  versioning {
    enabled = true
  }
  
  lifecycle_rule {
    condition {
      age = var.backup_retention_days
    }
    action {
      type = "Delete"
    }
  }
  
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }
  
  encryption {
    default_kms_key_name = var.kms_key_name
  }
  
  labels = merge(var.labels, {
    purpose     = "disaster-recovery"
    environment = var.environment
  })
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
    
    headers = {
      "Content-Type" = "application/json"
    }
    
    body = base64encode(jsonencode({
      project_id  = var.project_id
      environment = var.environment
      domains     = var.domains
      notification_email = var.notification_email
    }))
  }
  
  retry_config {
    retry_count = 3
  }
}

# Health check for DR readiness
resource "google_monitoring_uptime_check_config" "dr_readiness" {
  count        = var.enable_monitoring ? 1 : 0
  display_name = "DR Readiness Check - ${title(var.environment)}"
  timeout      = "10s"
  period       = "300s"
  
  http_check {
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"
    path           = "/health"
    
    accepted_response_status_codes {
      status_class = "STATUS_CLASS_2XX"
    }
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

# Notification channel for DR alerts
resource "google_monitoring_notification_channel" "dr_email" {
  count        = var.enable_monitoring ? 1 : 0
  display_name = "DR Email Notifications - ${title(var.environment)}"
  type         = "email"
  
  labels = {
    email_address = var.notification_email
  }
}

# Alert policy for DR failures
resource "google_monitoring_alert_policy" "dr_failure" {
  count        = var.enable_monitoring ? 1 : 0
  display_name = "DR Backup Failure Alert - ${title(var.environment)}"
  
  conditions {
    display_name = "DR backup job failure"
    
    condition_threshold {
      filter          = "resource.type="cloud_scheduler_job" resource.label.job_id="${google_cloud_scheduler_job.dr_backup.name}""
      duration        = "60s"
      comparison      = "COMPARISON_EQUAL"
      threshold_value = 1
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.dr_email[0].id]
  
  alert_strategy {
    auto_close = "1800s"
  }
}

# Custom IAM role for disaster recovery with least privilege
resource "google_project_iam_custom_role" "dr_backup_role" {
  role_id     = "drBackupRole${title(var.environment)}"
  title       = "Disaster Recovery Backup Role - ${title(var.environment)}"
  description = "Custom role for disaster recovery backup operations with least privilege"
  
  permissions = [
    "bigquery.datasets.get",
    "bigquery.jobs.create",
    "bigquery.tables.get",
    "bigquery.tables.getData",
    "storage.objects.create",
    "storage.objects.get",
    "storage.objects.list",
    "composer.environments.get",
    "monitoring.timeSeries.list",
    "cloudfunctions.functions.invoke"
  ]
}

# Service account for disaster recovery
resource "google_service_account" "dr_backup" {
  account_id   = "dr-backup-sa-${var.environment}"
  display_name = "Disaster Recovery Backup Service Account - ${title(var.environment)}"
  description  = "Service account for disaster recovery backup operations"
}

# IAM bindings with custom role and least privilege
resource "google_project_iam_member" "dr_backup_custom_role" {
  project = var.project_id
  role    = google_project_iam_custom_role.dr_backup_role.name
  member  = "serviceAccount:${google_service_account.dr_backup.email}"
}

# Additional minimal required roles
resource "google_project_iam_member" "dr_backup_storage" {
  count   = var.enable_cross_region_backup ? 1 : 0
  project = var.project_id
  role    = "roles/storage.objectCreator"  # Changed from objectAdmin to creator for least privilege
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
