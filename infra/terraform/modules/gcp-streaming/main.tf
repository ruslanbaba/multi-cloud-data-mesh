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
variable "network" { type = string }
variable "subnetwork" { type = string }

# Pub/Sub topics for each clinical domain
resource "google_pubsub_topic" "domain_streams" {
  for_each = toset(var.domains)
  name     = "${each.key}-stream-${var.environment}"
  
  labels = {
    environment = var.environment
    domain      = each.key
    dataclass   = "phi"
  }
  
  message_retention_duration = "86400s" # 24 hours
  
  schema_settings {
    schema   = google_pubsub_schema.domain_schema[each.key].name
    encoding = "JSON"
  }
}

# Schema definitions for data validation
resource "google_pubsub_schema" "domain_schema" {
  for_each = toset(var.domains)
  name     = "${each.key}-schema-${var.environment}"
  type     = "AVRO"
  
  definition = jsonencode({
    type = "record"
    name = "${title(each.key)}Event"
    fields = [
      {
        name = "patient_id"
        type = "string"
      },
      {
        name = "event_timestamp"
        type = "long"
        logicalType = "timestamp-millis"
      },
      {
        name = "event_data"
        type = "string"
      },
      {
        name = "source_system"
        type = "string"
      }
    ]
  })
}

# Subscriptions for Dataflow processing
resource "google_pubsub_subscription" "dataflow_subscriptions" {
  for_each = toset(var.domains)
  name     = "${each.key}-dataflow-sub-${var.environment}"
  topic    = google_pubsub_topic.domain_streams[each.key].name
  
  ack_deadline_seconds = 300
  
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq.id
    max_delivery_attempts = 5
  }
  
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }
  
  expiration_policy {
    ttl = "2678400s" # 31 days
  }
}

# Dead letter queue for failed messages
resource "google_pubsub_topic" "dlq" {
  name = "dead-letter-queue-${var.environment}"
  
  labels = {
    environment = var.environment
    purpose     = "dead-letter-queue"
  }
}

# Dataflow streaming jobs
resource "google_dataflow_job" "streaming_pipeline" {
  for_each = toset(var.domains)
  
  name                  = "${each.key}-streaming-${var.environment}"
  template_gcs_path     = "gs://dataflow-templates-${var.region}/latest/PubSub_to_BigQuery"
  temp_gcs_location     = "gs://${google_storage_bucket.dataflow_temp.name}/temp"
  zone                  = "${var.region}-a"
  max_workers           = 5
  on_delete             = "cancel"
  
  network    = var.network
  subnetwork = var.subnetwork
  
  parameters = {
    inputTopic               = google_pubsub_topic.domain_streams[each.key].id
    outputTableSpec          = "${var.project_id}:${each.key}_${var.environment}.${each.key}_streaming"
    createDisposition        = "CREATE_IF_NEEDED"
    writeDisposition         = "WRITE_APPEND"
    useStorageWriteApiAtLeastOnce = "true"
  }
  
  labels = {
    environment = var.environment
    domain      = each.key
    pipeline    = "streaming"
  }
}

# Temporary storage for Dataflow
resource "google_storage_bucket" "dataflow_temp" {
  name     = "${var.project_id}-dataflow-temp-${var.environment}"
  location = var.region
  
  uniform_bucket_level_access = true
  
  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "Delete"
    }
  }
}

# BigQuery streaming tables
resource "google_bigquery_table" "streaming_tables" {
  for_each   = toset(var.domains)
  project    = var.project_id
  dataset_id = "${each.key}_${var.environment}"
  table_id   = "${each.key}_streaming"
  
  time_partitioning {
    type                     = "DAY"
    field                    = "event_timestamp"
    require_partition_filter = true
    expiration_ms           = 2592000000 # 30 days
  }
  
  clustering = ["patient_id", "source_system"]
  
  schema = jsonencode([
    {
      name = "patient_id"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "event_timestamp"
      type = "TIMESTAMP"
      mode = "REQUIRED"
    },
    {
      name = "event_data"
      type = "JSON"
      mode = "NULLABLE"
    },
    {
      name = "source_system"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "_inserted_timestamp"
      type = "TIMESTAMP"
      mode = "NULLABLE"
    }
  ])
  
  labels = {
    environment = var.environment
    domain      = each.key
    table_type  = "streaming"
  }
}

# Cloud Function for real-time data validation
resource "google_cloudfunctions_function" "data_validator" {
  name                  = "data-validator-${var.environment}"
  runtime              = "python39"
  available_memory_mb  = 256
  source_archive_bucket = google_storage_bucket.function_source.name
  source_archive_object = google_storage_bucket_object.function_zip.name
  entry_point          = "validate_data"
  
  event_trigger {
    event_type = "providers/cloud.pubsub/eventTypes/topic.publish"
    resource   = values(google_pubsub_topic.domain_streams)[0].name
  }
  
  environment_variables = {
    PROJECT_ID  = var.project_id
    ENVIRONMENT = var.environment
  }
  
  labels = {
    environment = var.environment
    purpose     = "data-validation"
  }
}

resource "google_storage_bucket" "function_source" {
  name     = "${var.project_id}-functions-${var.environment}"
  location = var.region
}

resource "google_storage_bucket_object" "function_zip" {
  name   = "data-validator-${var.environment}.zip"
  bucket = google_storage_bucket.function_source.name
  source = "path/to/function.zip" # This would be built in CI/CD
}

output "pubsub_topics" {
  value = { for k, t in google_pubsub_topic.domain_streams : k => t.name }
}
output "streaming_tables" {
  value = { for k, t in google_bigquery_table.streaming_tables : k => "${t.project}.${t.dataset_id}.${t.table_id}" }
}
