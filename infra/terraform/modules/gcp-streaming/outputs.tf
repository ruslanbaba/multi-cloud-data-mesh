output "pubsub_topics" {
  description = "Map of domain names to Pub/Sub topic names"
  value       = { for k, topic in google_pubsub_topic.domain_streams : k => topic.name }
}

output "pubsub_topic_ids" {
  description = "Map of domain names to Pub/Sub topic IDs"
  value       = { for k, topic in google_pubsub_topic.domain_streams : k => topic.id }
}

output "subscriptions" {
  description = "Map of domain names to subscription names"
  value       = { for k, sub in google_pubsub_subscription.dataflow_subscriptions : k => sub.name }
}

output "streaming_tables" {
  description = "Map of domain names to BigQuery streaming table references"
  value = {
    for k, table in google_bigquery_table.streaming_tables :
    k => "${table.project}.${table.dataset_id}.${table.table_id}"
  }
}

output "dataflow_jobs" {
  description = "Map of domain names to Dataflow job names"
  value       = { for k, job in google_dataflow_job.streaming_pipeline : k => job.name }
}

output "dead_letter_topic" {
  description = "Dead letter queue topic name"
  value       = google_pubsub_topic.dlq.name
}

output "temp_bucket" {
  description = "Dataflow temporary storage bucket"
  value       = google_storage_bucket.dataflow_temp.name
}

output "schemas" {
  description = "Map of domain names to Pub/Sub schema names"
  value       = { for k, schema in google_pubsub_schema.domain_schema : k => schema.name }
}

output "data_validator_function" {
  description = "Data validation Cloud Function name"
  value       = google_cloudfunctions_function.data_validator.name
}
