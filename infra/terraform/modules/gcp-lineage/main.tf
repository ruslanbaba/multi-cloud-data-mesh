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
variable "kms_key_id" { type = string }

# Data Lineage API enable
resource "google_project_service" "lineage_api" {
  service = "datalineage.googleapis.com"
}

# Data Catalog for metadata management
resource "google_data_catalog_entry_group" "lineage_groups" {
  for_each = toset(var.domains)
  
  entry_group_id = "${each.key}-lineage-${var.environment}"
  display_name   = "${title(each.key)} Data Lineage"
  description    = "Data lineage tracking for ${each.key} domain"
  
  depends_on = [google_project_service.lineage_api]
}

# Custom entry types for lineage tracking
resource "google_data_catalog_entry" "data_assets" {
  for_each = toset([
    for domain in var.domains : "${domain}-dataset"
  ])
  
  entry_group = google_data_catalog_entry_group.lineage_groups[split("-", each.key)[0]].id
  entry_id    = each.key
  
  display_name = "${title(split("-", each.key)[0])} Dataset"
  description  = "BigQuery dataset for ${split("-", each.key)[0]} domain"
  
  type = "DATASET"
  
  bigquery_table_spec {
    table_source_type = "BIGQUERY_TABLE"
  }
  
  schema = jsonencode({
    columns = [
      {
        column = "patient_id"
        type   = "STRING"
        mode   = "REQUIRED"
      },
      {
        column = "event_timestamp"
        type   = "TIMESTAMP"
        mode   = "REQUIRED"
      }
    ]
  })
}

# Cloud Functions for lineage tracking
resource "google_cloudfunctions2_function" "lineage_tracker" {
  name        = "lineage-tracker-${var.environment}"
  location    = var.region
  description = "Tracks data lineage across multi-cloud data mesh"
  
  build_config {
    runtime     = "python311"
    entry_point = "track_lineage"
    
    source {
      storage_source {
        bucket = google_storage_bucket.lineage_functions.name
        object = google_storage_bucket_object.lineage_function_zip.name
      }
    }
  }
  
  service_config {
    max_instance_count = 10
    available_memory   = "512M"
    timeout_seconds    = 300
    
    environment_variables = {
      PROJECT_ID   = var.project_id
      ENVIRONMENT  = var.environment
      LINEAGE_API  = "datalineage.googleapis.com"
    }
    
    service_account_email = google_service_account.lineage_tracker.email
  }
  
  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.lineage_events.id
  }
}

# Pub/Sub topic for lineage events
resource "google_pubsub_topic" "lineage_events" {
  name = "lineage-events-${var.environment}"
  
  schema_settings {
    schema   = google_pubsub_schema.lineage_schema.name
    encoding = "JSON"
  }
}

resource "google_pubsub_schema" "lineage_schema" {
  name = "lineage-event-schema-${var.environment}"
  type = "AVRO"
  
  definition = jsonencode({
    type = "record"
    name = "LineageEvent"
    fields = [
      {
        name = "source_asset"
        type = "string"
      },
      {
        name = "target_asset"
        type = "string"
      },
      {
        name = "operation_type"
        type = {
          type = "enum"
          name = "OperationType"
          symbols = ["CREATE", "READ", "UPDATE", "DELETE", "TRANSFORM"]
        }
      },
      {
        name = "timestamp"
        type = "long"
        logicalType = "timestamp-millis"
      },
      {
        name = "user_id"
        type = "string"
      },
      {
        name = "job_id"
        type = ["null", "string"]
        default = null
      }
    ]
  })
}

# Service account for lineage tracking
resource "google_service_account" "lineage_tracker" {
  account_id   = "lineage-tracker-${var.environment}"
  display_name = "Data Lineage Tracker"
}

resource "google_project_iam_member" "lineage_tracker_roles" {
  for_each = toset([
    "roles/datacatalog.admin",
    "roles/datalineage.admin",
    "roles/bigquery.metadataViewer",
    "roles/pubsub.subscriber"
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.lineage_tracker.email}"
}

# Storage for function source
resource "google_storage_bucket" "lineage_functions" {
  name     = "${var.project_id}-lineage-functions-${var.environment}"
  location = var.region
  
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "lineage_function_zip" {
  name   = "lineage-tracker-${var.environment}.zip"
  bucket = google_storage_bucket.lineage_functions.name
  source = "path/to/lineage-function.zip" # Built in CI/CD
}

# BigQuery views for lineage reporting
resource "google_bigquery_dataset" "lineage_reporting" {
  dataset_id  = "lineage_reporting_${var.environment}"
  description = "Dataset for data lineage reporting and analytics"
  location    = var.region
  
  labels = {
    environment = var.environment
    purpose     = "lineage-reporting"
  }
}

resource "google_bigquery_table" "lineage_events_table" {
  dataset_id = google_bigquery_dataset.lineage_reporting.dataset_id
  table_id   = "lineage_events"
  
  time_partitioning {
    type  = "DAY"
    field = "event_timestamp"
  }
  
  schema = jsonencode([
    {
      name = "source_asset"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "target_asset"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "operation_type"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "event_timestamp"
      type = "TIMESTAMP"
      mode = "REQUIRED"
    },
    {
      name = "user_id"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "job_id"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "metadata"
      type = "JSON"
      mode = "NULLABLE"
    }
  ])
}

# Scheduled queries for lineage analytics
resource "google_bigquery_data_transfer_config" "lineage_analytics" {
  display_name           = "lineage-analytics-${var.environment}"
  location              = var.region
  data_source_id        = "scheduled_query"
  schedule              = "every day 02:00"
  destination_dataset_id = google_bigquery_dataset.lineage_reporting.dataset_id
  
  params = {
    destination_table_name_template = "daily_lineage_summary_{run_date}"
    write_disposition              = "WRITE_TRUNCATE"
    query = templatefile("${path.module}/sql/lineage_summary.sql", {
      project_id  = var.project_id
      environment = var.environment
    })
  }
  
  service_account_name = google_service_account.lineage_analytics.email
}

resource "google_service_account" "lineage_analytics" {
  account_id   = "lineage-analytics-${var.environment}"
  display_name = "Lineage Analytics Service Account"
}

resource "google_project_iam_member" "lineage_analytics_roles" {
  for_each = toset([
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser"
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.lineage_analytics.email}"
}

# Data Studio dashboard for lineage visualization
resource "google_bigquery_table" "lineage_dashboard_view" {
  dataset_id = google_bigquery_dataset.lineage_reporting.dataset_id
  table_id   = "lineage_dashboard_view"
  
  view {
    query = templatefile("${path.module}/sql/lineage_dashboard.sql", {
      project_id  = var.project_id
      environment = var.environment
    })
    use_legacy_sql = false
  }
}

# Apache Atlas integration (via GKE deployment)
resource "google_container_cluster" "atlas_cluster" {
  name     = "atlas-lineage-${var.environment}"
  location = var.region
  
  remove_default_node_pool = true
  initial_node_count       = 1
  
  network    = var.network
  subnetwork = var.subnetwork
  
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  
  database_encryption {
    state    = "ENCRYPTED"
    key_name = var.kms_key_id
  }
}

resource "google_container_node_pool" "atlas_nodes" {
  name       = "atlas-node-pool"
  location   = var.region
  cluster    = google_container_cluster.atlas_cluster.name
  node_count = 2
  
  node_config {
    preemptible  = false
    machine_type = "e2-standard-4"
    
    service_account = google_service_account.atlas_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

resource "google_service_account" "atlas_nodes" {
  account_id   = "atlas-nodes-${var.environment}"
  display_name = "Atlas Nodes Service Account"
}

output "lineage_topic" {
  value = google_pubsub_topic.lineage_events.name
}

output "lineage_dataset" {
  value = google_bigquery_dataset.lineage_reporting.dataset_id
}

output "atlas_cluster" {
  value = google_container_cluster.atlas_cluster.name
}
