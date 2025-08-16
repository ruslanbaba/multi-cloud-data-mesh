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
variable "region" { type = string }
variable "environment" { type = string }
variable "domains" { type = list(string) }

# BigQuery slot reservations for cost optimization
resource "google_bigquery_reservation" "data_mesh_reservation" {
  name                = "data-mesh-reservation-${var.environment}"
  location            = var.region
  slot_capacity       = var.environment == "prod" ? 2000 : 500
  ignore_idle_slots   = true
  concurrency         = 0 # Auto-scaling
  multi_region_auxiliary = false
  
  autoscale {
    max_slots = var.environment == "prod" ? 5000 : 1000
  }
}

# Reservation assignments
resource "google_bigquery_assignment" "domain_assignments" {
  for_each = toset(var.domains)
  
  assignee     = "projects/${var.project_id}/datasets/${each.key}_${var.environment}"
  job_type     = "QUERY"
  reservation  = google_bigquery_reservation.data_mesh_reservation.id
}

# BI Engine reservations for fast analytics
resource "google_bigquery_bi_reservation" "analytics_reservation" {
  location = var.region
  size     = var.environment == "prod" ? 10737418240 : 2147483648 # 10GB prod, 2GB non-prod
  
  preferred_tables {
    project_id = var.project_id
    dataset_id = "patient_demographics_${var.environment}"
    table_id   = "patients"
  }
}

# Storage lifecycle policies for BigQuery
resource "google_storage_bucket" "bq_exports" {
  name     = "${var.project_id}-bq-exports-${var.environment}"
  location = var.region
  
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }
  
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }
  
  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type = "SetStorageClass"
      storage_class = "ARCHIVE"
    }
  }
}

# Cost monitoring and alerting
resource "google_monitoring_alert_policy" "bigquery_cost_alert" {
  display_name = "BigQuery Cost Alert - ${var.environment}"
  combiner     = "OR"
  
  conditions {
    display_name = "BigQuery slot hours exceeded"
    
    condition_threshold {
      filter         = "resource.type=\"bigquery_project\""
      comparison     = "COMPARISON_GREATER_THAN"
      threshold_value = var.environment == "prod" ? 10000 : 2000
      duration       = "300s"
      
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.cost_alerts.name]
  
  alert_strategy {
    auto_close = "86400s" # 24 hours
  }
}

resource "google_monitoring_notification_channel" "cost_alerts" {
  display_name = "Cost Alerts - ${var.environment}"
  type         = "email"
  
  labels = {
    email_address = "cost-alerts@example.com"
  }
}

# Budget alerts
resource "google_billing_budget" "data_mesh_budget" {
  billing_account = var.billing_account_id
  display_name    = "Data Mesh Budget - ${var.environment}"
  
  budget_filter {
    projects = ["projects/${var.project_id}"]
    services = [
      "services/24E6-581D-38E5", # BigQuery
      "services/A1E8-BE35-7EBC", # Cloud Storage
      "services/6F81-5844-456A"  # Compute Engine
    ]
  }
  
  amount {
    specified_amount {
      currency_code = "USD"
      units = var.environment == "prod" ? "50000" : "10000"
    }
  }
  
  threshold_rules {
    threshold_percent = 0.8
    spend_basis      = "CURRENT_SPEND"
  }
  
  threshold_rules {
    threshold_percent = 1.0
    spend_basis      = "CURRENT_SPEND"
  }
  
  all_updates_rule {
    monitoring_notification_channels = [google_monitoring_notification_channel.cost_alerts.name]
  }
}

# Scheduled queries for cost analysis
resource "google_bigquery_data_transfer_config" "cost_analysis" {
  display_name           = "cost-analysis-${var.environment}"
  location              = var.region
  data_source_id        = "scheduled_query"
  schedule              = "every day 06:00"
  destination_dataset_id = google_bigquery_dataset.cost_analytics.dataset_id
  
  params = {
    destination_table_name_template = "daily_cost_analysis_{run_date}"
    write_disposition              = "WRITE_TRUNCATE"
    query = templatefile("${path.module}/sql/cost_analysis.sql", {
      project_id  = var.project_id
      environment = var.environment
    })
  }
  
  service_account_name = google_service_account.cost_analytics.email
}

resource "google_bigquery_dataset" "cost_analytics" {
  dataset_id  = "cost_analytics_${var.environment}"
  description = "Dataset for cost analysis and optimization"
  location    = var.region
  
  labels = {
    environment = var.environment
    purpose     = "cost-optimization"
  }
}

resource "google_service_account" "cost_analytics" {
  account_id   = "cost-analytics-${var.environment}"
  display_name = "Cost Analytics Service Account"
}

resource "google_project_iam_member" "cost_analytics_roles" {
  for_each = toset([
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
    "roles/billing.viewer"
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cost_analytics.email}"
}

# BigQuery table clustering for cost optimization
resource "google_bigquery_table" "optimized_tables" {
  for_each = toset(var.domains)
  
  dataset_id = "${each.key}_${var.environment}"
  table_id   = "${each.key}_optimized"
  
  time_partitioning {
    type                     = "DAY"
    field                    = "event_date"
    require_partition_filter = true
    expiration_ms           = 7776000000 # 90 days
  }
  
  clustering = ["patient_id", "provider_id", "event_type"]
  
  range_partitioning {
    field = "patient_age_group"
    range {
      start    = 0
      end      = 100
      interval = 10
    }
  }
  
  schema = jsonencode([
    {
      name = "patient_id"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "event_date"
      type = "DATE"
      mode = "REQUIRED"
    },
    {
      name = "patient_age_group"
      type = "INTEGER"
      mode = "REQUIRED"
    },
    {
      name = "provider_id"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "event_type"
      type = "STRING"
      mode = "REQUIRED"
    }
  ])
  
  labels = {
    environment = var.environment
    domain      = each.key
    optimized   = "true"
  }
}

# Materialized views for frequently accessed data
resource "google_bigquery_table" "materialized_views" {
  for_each = toset([
    "patient_summary", "provider_metrics", "quality_indicators"
  ])
  
  dataset_id = "analytics_${var.environment}"
  table_id   = "${each.key}_mv"
  
  materialized_view {
    query = templatefile("${path.module}/sql/${each.key}_mv.sql", {
      project_id  = var.project_id
      environment = var.environment
    })
    enable_refresh = true
    refresh_interval_ms = 3600000 # 1 hour
  }
  
  labels = {
    environment = var.environment
    view_type   = "materialized"
    purpose     = each.key
  }
}

# Cloud Functions for automated cost optimization
resource "google_cloudfunctions2_function" "cost_optimizer" {
  name        = "cost-optimizer-${var.environment}"
  location    = var.region
  description = "Automated cost optimization for data mesh"
  
  build_config {
    runtime     = "python311"
    entry_point = "optimize_costs"
    
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.optimizer_zip.name
      }
    }
  }
  
  service_config {
    max_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 300
    
    environment_variables = {
      PROJECT_ID   = var.project_id
      ENVIRONMENT  = var.environment
    }
    
    service_account_email = google_service_account.cost_optimizer.email
  }
  
  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.scheduler.job.v1.executed"
    
    event_filters {
      attribute = "jobName"
      value     = google_cloud_scheduler_job.cost_optimization.name
    }
  }
}

resource "google_cloud_scheduler_job" "cost_optimization" {
  name     = "cost-optimization-${var.environment}"
  schedule = "0 2 * * *" # Daily at 2 AM
  region   = var.region
  
  pubsub_target {
    topic_name = google_pubsub_topic.cost_optimization.id
    data       = base64encode(jsonencode({
      action = "optimize_costs"
      environment = var.environment
    }))
  }
}

resource "google_pubsub_topic" "cost_optimization" {
  name = "cost-optimization-${var.environment}"
}

resource "google_storage_bucket" "function_source" {
  name     = "${var.project_id}-cost-optimizer-${var.environment}"
  location = var.region
}

resource "google_storage_bucket_object" "optimizer_zip" {
  name   = "cost-optimizer-${var.environment}.zip"
  bucket = google_storage_bucket.function_source.name
  source = "path/to/optimizer.zip" # Built in CI/CD
}

resource "google_service_account" "cost_optimizer" {
  account_id   = "cost-optimizer-${var.environment}"
  display_name = "Cost Optimizer Service Account"
}

resource "google_project_iam_member" "cost_optimizer_roles" {
  for_each = toset([
    "roles/bigquery.admin",
    "roles/storage.admin",
    "roles/monitoring.metricWriter"
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cost_optimizer.email}"
}

variable "billing_account_id" {
  description = "Billing account ID for budget alerts"
  type        = string
}

output "reservation_name" {
  value = google_bigquery_reservation.data_mesh_reservation.name
}

output "cost_analytics_dataset" {
  value = google_bigquery_dataset.cost_analytics.dataset_id
}

output "bi_reservation_size" {
  value = google_bigquery_bi_reservation.analytics_reservation.size
}
