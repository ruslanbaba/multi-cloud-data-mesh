output "workbench_instance" {
  description = "ML Workbench instance name"
  value       = google_notebooks_instance.ml_workbench.name
}

output "workbench_proxy_uri" {
  description = "ML Workbench proxy URI for secure access"
  value       = google_notebooks_instance.ml_workbench.proxy_uri
  sensitive   = true
}

output "model_endpoints" {
  description = "Map of model names to endpoint names"
  value       = { for k, endpoint in google_vertex_ai_endpoint.model_endpoints : k => endpoint.name }
}

output "model_endpoint_ids" {
  description = "Map of model names to endpoint IDs"
  value       = { for k, endpoint in google_vertex_ai_endpoint.model_endpoints : k => endpoint.id }
  sensitive   = true
}

output "featurestore_id" {
  description = "Feature Store ID"
  value       = google_vertex_ai_featurestore.clinical_features.id
}

output "featurestore_name" {
  description = "Feature Store name"
  value       = google_vertex_ai_featurestore.clinical_features.name
}

output "ml_pipeline_trigger_id" {
  description = "Cloud Build trigger ID for ML pipeline"
  value       = google_cloudbuild_trigger.ml_pipeline.id
}

output "workbench_service_account" {
  description = "Service account email for ML workbench"
  value       = google_service_account.ml_workbench.email
}

output "pipeline_service_account" {
  description = "Service account email for ML pipeline"
  value       = google_service_account.ml_pipeline.email
}

output "custom_roles" {
  description = "Custom IAM roles created for ML operations"
  value = {
    workbench_limited = google_project_iam_custom_role.ml_workbench_limited.name
    pipeline_limited  = google_project_iam_custom_role.ml_pipeline_limited.name
  }
}

output "model_registry" {
  description = "Map of clinical models in the registry"
  value       = { for k, model in google_vertex_ai_model.clinical_models : k => model.name }
}

output "training_pipelines" {
  description = "Map of AutoML training pipelines"
  value       = { for k, pipeline in google_vertex_ai_training_pipeline.automl_pipelines : k => pipeline.name }
}

output "ml_datasets" {
  description = "Map of ML datasets for training"
  value       = { for k, dataset in google_vertex_ai_dataset.ml_datasets : k => dataset.name }
}

output "monitoring_jobs" {
  description = "Map of model monitoring job names"
  value       = { for k, job in google_vertex_ai_model_deployment_monitoring_job.model_monitoring : k => job.name }
}

output "security_configuration" {
  description = "Security configuration summary"
  value = {
    encryption_enabled    = true
    kms_key_id           = var.kms_key_id
    private_network      = var.network_name != null
    audit_logging        = var.enable_audit_logging
    custom_roles_count   = 2
    authorized_users     = length(var.allowed_users)
  }
  sensitive = true
}

output "workbench_instance_url" {
  description = "URL to access ML Workbench in Google Cloud Console"
  value       = "https://console.cloud.google.com/vertex-ai/workbench/instances/details/${var.region}-a/${google_notebooks_instance.ml_workbench.name}?project=${var.project_id}"
}

output "vertex_ai_dashboard_url" {
  description = "URL to Vertex AI dashboard"
  value       = "https://console.cloud.google.com/vertex-ai?project=${var.project_id}"
}

output "model_registry_url" {
  description = "URL to Vertex AI Model Registry"
  value       = "https://console.cloud.google.com/vertex-ai/models?project=${var.project_id}"
}

output "feature_store_url" {
  description = "URL to Vertex AI Feature Store"
  value       = "https://console.cloud.google.com/vertex-ai/feature-store?project=${var.project_id}"
}
