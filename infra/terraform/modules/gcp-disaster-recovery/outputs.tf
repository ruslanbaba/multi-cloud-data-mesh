output "dr_datasets" {
  description = "Map of domain names to disaster recovery dataset IDs"
  value       = { for k, d in google_bigquery_dataset.dr_datasets : k => d.dataset_id }
}

output "dr_backup_bucket" {
  description = "Name of the disaster recovery backup bucket"
  value       = var.enable_cross_region_backup ? google_storage_bucket.dr_backup[0].name : null
}

output "dr_backup_service_account" {
  description = "Email of the disaster recovery backup service account"
  value       = google_service_account.dr_backup.email
}

output "backup_job_name" {
  description = "Name of the backup scheduler job"
  value       = google_cloud_scheduler_job.dr_backup.name
}

output "monitoring_check_id" {
  description = "ID of the disaster recovery monitoring check"
  value       = var.enable_monitoring ? google_monitoring_uptime_check_config.dr_readiness[0].uptime_check_id : null
}

output "transfer_configs" {
  description = "Map of domain names to transfer configuration IDs"
  value       = { for k, config in google_bigquery_data_transfer_config.cross_region_transfer : k => config.id }
}
