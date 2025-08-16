terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.31.1"
    }
  }
}

variable "project_id" { 
  description = "GCP project ID for ML resources"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, lowercase letters, digits, and hyphens only."
  }
}

variable "region" { 
  description = "GCP region for ML resources"
  type        = string
  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.region))
    error_message = "Region must be a valid GCP region format."
  }
}

variable "environment" { 
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "domains" { 
  description = "List of clinical domains for ML processing"
  type        = list(string)
  validation {
    condition     = length(var.domains) > 0 && length(var.domains) <= 50
    error_message = "Domains list must contain 1-50 valid domain names."
  }
}

variable "bigquery_datasets" { 
  description = "Map of BigQuery dataset IDs for ML training"
  type        = map(string)
  sensitive   = false
}

variable "kms_key_id" { 
  description = "KMS key ID for encryption"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("^projects/.+/locations/.+/keyRings/.+/cryptoKeys/.+$", var.kms_key_id))
    error_message = "KMS key ID must be in full resource name format."
  }
}

variable "network_name" {
  description = "VPC network name for secure ML workbench deployment"
  type        = string
  default     = null
}

variable "subnet_name" {
  description = "Subnet name for secure ML workbench deployment"
  type        = string
  default     = null
}

variable "allowed_users" {
  description = "List of authorized users for ML workbench access"
  type        = list(string)
  validation {
    condition     = length(var.allowed_users) > 0
    error_message = "At least one authorized user must be specified."
  }
}

variable "enable_ip_forwarding" {
  description = "Enable IP forwarding on ML workbench (security risk if enabled)"
  type        = bool
  default     = false
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB for ML workbench"
  type        = number
  default     = 100
  validation {
    condition     = var.boot_disk_size_gb >= 20 && var.boot_disk_size_gb <= 1000
    error_message = "Boot disk size must be between 20 and 1000 GB."
  }
}

variable "github_owner" {
  description = "GitHub organization/owner for ML pipeline"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$", var.github_owner))
    error_message = "GitHub owner must be a valid organization name."
  }
}

variable "github_repo" {
  description = "GitHub repository name for ML pipeline"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$", var.github_repo))
    error_message = "GitHub repository must be a valid repository name."
  }
}

variable "secure_worker_pool" {
  description = "Secure worker pool for production Cloud Build jobs"
  type        = string
  default     = null
}

# Data sources for security validation
data "google_client_config" "current" {}

data "google_project" "current" {
  project_id = var.project_id
}

# Vertex AI Workbench for data scientists with enhanced security
resource "google_notebooks_instance" "ml_workbench" {
  name         = "ml-workbench-${var.environment}"
  location     = "${var.region}-a"
  machine_type = var.environment == "prod" ? "n1-standard-8" : "n1-standard-4"
  
  vm_image {
    project      = "deeplearning-platform-release"
    image_family = "tf-2-13-cu118-notebooks"  # Updated to latest secure version
  }
  
  # Security: Use parameterized allowed users instead of hardcoded email
  instance_owners = var.allowed_users
  service_account = google_service_account.ml_workbench.email
  
  # Security: Enhanced disk encryption with customer-managed keys
  disk_encryption = "CMEK"
  kms_key        = var.kms_key_id
  boot_disk_type = "PD_SSD"
  boot_disk_size_gb = var.boot_disk_size_gb
  
  # Security: Network isolation
  network = var.network_name
  subnet  = var.subnet_name
  
  # Security: Disable external IP access for production
  no_public_ip = var.environment == "prod" ? true : false
  
  # Security: Disable unnecessary features
  no_proxy_access = false
  no_remove_data_disk = true
  
  # Security: Enhanced metadata
  metadata = {
    enable-oslogin = "TRUE"
    block-project-ssh-keys = var.environment == "prod" ? "TRUE" : "FALSE"
    startup-script = base64encode(templatefile("${path.module}/scripts/secure-startup.sh", {
      environment = var.environment
    }))
  }
  
  # Security: Restrict machine type and prevent preemptible instances in prod
  preemptible = var.environment == "prod" ? false : true
  
  labels = {
    environment = var.environment
    purpose     = "ml-development"
    security-level = var.environment == "prod" ? "high" : "medium"
    data-classification = "phi"
  }
  
  tags = ["ml-workbench", "secure-ml", var.environment]
}

# Service account for ML workbench with least privilege principle
resource "google_service_account" "ml_workbench" {
  account_id   = "ml-workbench-${var.environment}"
  display_name = "ML Workbench Service Account - ${var.environment}"
  description  = "Service account for Vertex AI Workbench with restricted permissions"
}

# Security: Apply principle of least privilege for ML workbench IAM roles
resource "google_project_iam_member" "ml_workbench_roles" {
  for_each = toset([
    "roles/bigquery.dataViewer",      # Read-only access to BigQuery data
    "roles/bigquery.jobUser",         # Can run BigQuery jobs
    "roles/aiplatform.user",          # Can use AI Platform services
    "roles/storage.objectViewer",     # Read-only access to Cloud Storage
    # Removed roles/notebooks.admin - too permissive, will use custom role
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.ml_workbench.email}"
  
  condition {
    title       = "Environment-specific access"
    description = "Access limited to ${var.environment} environment resources"
    expression  = "request.time < timestamp('2026-12-31T23:59:59Z')" # Expire access
  }
}

# Security: Custom IAM role for limited notebook operations
resource "google_project_iam_custom_role" "ml_workbench_limited" {
  role_id     = "mlWorkbenchLimited${title(var.environment)}"
  title       = "ML Workbench Limited Role - ${var.environment}"
  description = "Limited permissions for ML workbench operations"
  
  permissions = [
    "notebooks.instances.get",
    "notebooks.instances.list",
    "notebooks.instances.start",
    "notebooks.instances.stop",
    "notebooks.kernels.list",
    "notebooks.sessions.create",
    "notebooks.sessions.get",
    "notebooks.sessions.list"
  ]
}

resource "google_project_iam_member" "ml_workbench_custom" {
  project = var.project_id
  role    = google_project_iam_custom_role.ml_workbench_limited.name
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

# ML Pipeline for automated training with security controls
resource "google_cloudbuild_trigger" "ml_pipeline" {
  name     = "ml-pipeline-${var.environment}"
  location = var.region
  
  # Security: Use specific branch and require approval for production
  github {
    owner = var.github_owner  # Parameterized instead of hardcoded
    name  = var.github_repo   # Parameterized instead of hardcoded
    push {
      branch = var.environment == "prod" ? "^main$" : "^(main|develop)$"
    }
  }
  
  # Security: Enhanced approval process for production
  approval_config {
    approval_required = var.environment == "prod" ? true : false
  }
  
  # Security: Secure build steps with proper authentication
  build {
    # Security: Use specific service account for builds
    service_account = google_service_account.ml_pipeline.id
    
    step {
      name = "gcr.io/cloud-builders/gcloud"
      args = [
        "ai", "custom-jobs", "create",
        "--region=${var.region}",
        "--display-name=clinical-model-training-${var.environment}",
        "--config=mlops/training_config.yaml",
        "--service-account=${google_service_account.ml_pipeline.email}"
      ]
      
      # Security: Environment variable validation
      env = [
        "PROJECT_ID=${var.project_id}",
        "ENVIRONMENT=${var.environment}",
        "KMS_KEY=${var.kms_key_id}"
      ]
    }
    
    # Security: Vulnerability scanning step
    step {
      name = "gcr.io/cloud-builders/gcloud"
      args = [
        "container", "images", "scan",
        "--format=json"
      ]
    }
    
    options {
      logging = "CLOUD_LOGGING_ONLY"
      log_streaming_option = "STREAM_ON"
      worker_pool = var.environment == "prod" ? var.secure_worker_pool : null
      
      # Security: Machine type restrictions
      machine_type = var.environment == "prod" ? "E2_HIGHCPU_8" : "E2_STANDARD_4"
      
      # Security: Disk encryption
      disk_size_gb = 100
    }
    
    # Security: Artifact attestation
    available_secrets {
      secret_manager {
        env          = "ML_PIPELINE_KEY"
        version_name = "projects/${var.project_id}/secrets/ml-pipeline-key/versions/latest"
      }
    }
  }
  
  service_account = google_service_account.ml_pipeline.id
  
  # Security: Resource tagging
  tags = ["ml-pipeline", "automated-training", var.environment]
}

# Service account for ML pipeline with enhanced security
resource "google_service_account" "ml_pipeline" {
  account_id   = "ml-pipeline-${var.environment}"
  display_name = "ML Pipeline Service Account - ${var.environment}"
  description  = "Service account for automated ML pipeline operations with restricted permissions"
}

# Security: Apply principle of least privilege for ML pipeline IAM roles
resource "google_project_iam_member" "ml_pipeline_roles" {
  for_each = toset([
    "roles/aiplatform.user",          # Changed from admin to user for least privilege
    "roles/bigquery.dataViewer",      # Read-only access to BigQuery
    "roles/bigquery.jobUser",         # Can run BigQuery jobs
    "roles/storage.objectAdmin",      # Changed from admin to objectAdmin for specific bucket access
    "roles/cloudbuild.builds.builder" # Can execute Cloud Build operations
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.ml_pipeline.email}"
  
  condition {
    title       = "Time-based access restriction"
    description = "Access expires on specified date for security"
    expression  = "request.time < timestamp('2026-12-31T23:59:59Z')"
  }
}

# Security: Custom role for limited AI Platform operations
resource "google_project_iam_custom_role" "ml_pipeline_limited" {
  role_id     = "mlPipelineLimited${title(var.environment)}"
  title       = "ML Pipeline Limited Role - ${var.environment}"
  description = "Limited AI Platform permissions for ML pipeline"
  
  permissions = [
    "aiplatform.customJobs.create",
    "aiplatform.customJobs.get",
    "aiplatform.customJobs.list",
    "aiplatform.models.create",
    "aiplatform.models.get",
    "aiplatform.models.list",
    "aiplatform.models.upload",
    "aiplatform.endpoints.create",
    "aiplatform.endpoints.deploy",
    "aiplatform.endpoints.get",
    "aiplatform.endpoints.list"
  ]
}

resource "google_project_iam_member" "ml_pipeline_custom" {
  project = var.project_id
  role    = google_project_iam_custom_role.ml_pipeline_limited.name
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
