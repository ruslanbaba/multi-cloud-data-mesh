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
variable "bigquery_datasets" { type = map(string) }
variable "kms_key_id" { type = string }

# Vertex AI Workbench for data scientists
resource "google_notebooks_instance" "ml_workbench" {
  name         = "ml-workbench-${var.environment}"
  location     = "${var.region}-a"
  machine_type = "n1-standard-4"
  
  vm_image {
    project      = "deeplearning-platform-release"
    image_family = "tf-2-11-cu113-notebooks"
  }
  
  instance_owners = ["data-science-team@example.com"]
  service_account = google_service_account.ml_workbench.email
  
  disk_encryption = "CMEK"
  kms_key        = var.kms_key_id
  
  labels = {
    environment = var.environment
    purpose     = "ml-development"
  }
}

# Service account for ML workbench
resource "google_service_account" "ml_workbench" {
  account_id   = "ml-workbench-${var.environment}"
  display_name = "ML Workbench Service Account"
}

# IAM roles for ML workbench
resource "google_project_iam_member" "ml_workbench_roles" {
  for_each = toset([
    "roles/bigquery.dataViewer",
    "roles/bigquery.jobUser",
    "roles/aiplatform.user",
    "roles/storage.objectViewer",
    "roles/notebooks.admin"
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.ml_workbench.email}"
}

# Vertex AI Model Registry
resource "google_vertex_ai_model" "clinical_models" {
  for_each = toset([
    "risk_prediction", "readmission_forecast", "diagnosis_assistant",
    "drug_interaction", "clinical_nlp", "outcome_prediction"
  ])
  
  display_name = "${each.key}-model-${var.environment}"
  region       = var.region
  
  labels = {
    environment = var.environment
    model_type  = each.key
    domain      = "clinical"
  }
  
  encryption_spec {
    kms_key_name = var.kms_key_id
  }
}

# Vertex AI Endpoints for model serving
resource "google_vertex_ai_endpoint" "model_endpoints" {
  for_each = google_vertex_ai_model.clinical_models
  
  display_name = "${each.key}-endpoint-${var.environment}"
  location     = var.region
  region       = var.region
  
  labels = {
    environment = var.environment
    model_type  = each.key
  }
  
  encryption_spec {
    kms_key_name = var.kms_key_id
  }
}

# Feature Store for ML features
resource "google_vertex_ai_featurestore" "clinical_features" {
  name     = "clinical-features-${var.environment}"
  region   = var.region
  
  labels = {
    environment = var.environment
    purpose     = "clinical-ml"
  }
  
  encryption_spec {
    kms_key_name = var.kms_key_id
  }
  
  online_serving_config {
    fixed_node_count = 1
  }
}

# Feature Store entity types
resource "google_vertex_ai_featurestore_entitytype" "entities" {
  for_each = toset(["patient", "encounter", "provider", "medication", "diagnosis"])
  
  name         = each.key
  featurestore = google_vertex_ai_featurestore.clinical_features.id
  
  labels = {
    environment = var.environment
    entity_type = each.key
  }
  
  monitoring_config {
    snapshot_analysis {
      disabled = false
    }
  }
}

# ML Pipeline for automated training
resource "google_cloudbuild_trigger" "ml_pipeline" {
  name     = "ml-pipeline-${var.environment}"
  location = var.region
  
  github {
    owner = "your-organization"
    name  = "multi-cloud-data-mesh"
    push {
      branch = "^main$"
    }
  }
  
  build {
    step {
      name = "gcr.io/cloud-builders/gcloud"
      args = [
        "ai", "custom-jobs", "create",
        "--region=${var.region}",
        "--display-name=clinical-model-training-${var.environment}",
        "--config=mlops/training_config.yaml"
      ]
    }
    
    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }
  
  service_account = google_service_account.ml_pipeline.id
}

# Service account for ML pipeline
resource "google_service_account" "ml_pipeline" {
  account_id   = "ml-pipeline-${var.environment}"
  display_name = "ML Pipeline Service Account"
}

# IAM roles for ML pipeline
resource "google_project_iam_member" "ml_pipeline_roles" {
  for_each = toset([
    "roles/aiplatform.admin",
    "roles/bigquery.dataViewer",
    "roles/bigquery.jobUser",
    "roles/storage.admin",
    "roles/cloudbuild.builds.builder"
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.ml_pipeline.email}"
}

# Model monitoring jobs
resource "google_vertex_ai_model_deployment_monitoring_job" "model_monitoring" {
  for_each = google_vertex_ai_endpoint.model_endpoints
  
  display_name = "${each.key}-monitoring-${var.environment}"
  endpoint     = each.value.id
  
  model_deployment_monitoring_objective_configs {
    deployed_model_id = each.value.id
    
    objective_config {
      training_dataset {
        bigquery_source {
          input_uri = "bq://${var.project_id}.ml_${var.environment}.training_data"
        }
      }
      
      training_prediction_skew_detection_config {
        skew_thresholds = {
          "feature1" = 0.1
          "feature2" = 0.1
        }
      }
      
      prediction_drift_detection_config {
        drift_thresholds = {
          "feature1" = 0.1
          "feature2" = 0.1
        }
      }
    }
  }
  
  model_deployment_monitoring_schedule_config {
    monitor_interval = "3600s" # 1 hour
  }
  
  logging_sampling_strategy {
    random_sample_config {
      sample_rate = 0.1
    }
  }
  
  labels = {
    environment = var.environment
    model_type  = each.key
  }
}

# BigQuery ML models for federated learning
resource "google_bigquery_routine" "ml_models" {
  for_each = toset([
    "patient_risk_model", "readmission_model", "treatment_response_model"
  ])
  
  dataset_id      = "ml_${var.environment}"
  routine_id      = each.key
  routine_type    = "PROCEDURE"
  language        = "SQL"
  
  definition_body = templatefile("${path.module}/sql/${each.key}.sql", {
    project_id  = var.project_id
    environment = var.environment
  })
  
  arguments {
    name      = "model_name"
    data_type = jsonencode({ "typeKind" = "STRING" })
  }
}

# AutoML training jobs
resource "google_vertex_ai_training_pipeline" "automl_pipelines" {
  for_each = toset(["tabular_classification", "tabular_regression", "text_classification"])
  
  display_name = "${each.key}-pipeline-${var.environment}"
  location     = var.region
  
  training_task_definition = "gs://google-cloud-aiplatform/schema/trainingjob/definition/automl_${each.key}_1.0.0.yaml"
  
  training_task_inputs = jsonencode({
    targetColumn = "target"
    predictionType = each.key == "tabular_regression" ? "regression" : "classification"
    transformations = [
      {
        auto = {
          columnName = "feature1"
        }
      }
    ]
    datasetId = google_vertex_ai_dataset.ml_datasets[each.key].id
    modelDisplayName = "${each.key}-model-${var.environment}"
  })
  
  labels = {
    environment = var.environment
    pipeline_type = each.key
  }
  
  encryption_spec {
    kms_key_name = var.kms_key_id
  }
}

# ML datasets
resource "google_vertex_ai_dataset" "ml_datasets" {
  for_each = toset(["tabular_classification", "tabular_regression", "text_classification"])
  
  display_name   = "${each.key}-dataset-${var.environment}"
  metadata_schema_uri = each.key == "text_classification" ? 
    "gs://google-cloud-aiplatform/schema/dataset/metadata/text_1.0.0.yaml" :
    "gs://google-cloud-aiplatform/schema/dataset/metadata/tabular_1.0.0.yaml"
  
  region = var.region
  
  labels = {
    environment = var.environment
    dataset_type = each.key
  }
  
  encryption_spec {
    kms_key_name = var.kms_key_id
  }
}

output "workbench_instance" {
  value = google_notebooks_instance.ml_workbench.name
}

output "model_endpoints" {
  value = { for k, endpoint in google_vertex_ai_endpoint.model_endpoints : k => endpoint.name }
}

output "featurestore_id" {
  value = google_vertex_ai_featurestore.clinical_features.id
}
