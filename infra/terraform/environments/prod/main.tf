# Advanced multi-cloud data mesh with next-level enterprise capabilities
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.31.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.45.0"
    }
  }
}

# Provider configurations with OIDC authentication
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "multi-cloud-data-mesh"
      ManagedBy   = "terraform"
    }
  }
}

# Core infrastructure modules
module "aws_s3" {
  source = "../../modules/aws"
  
  environment     = var.environment
  s3_bucket_name = "${var.project_name}-${var.environment}"
  domains        = var.clinical_domains
  kms_key_id     = module.aws_kms.key_id
}

module "aws_kms" {
  source = "../../modules/aws-kms"
  
  environment = var.environment
}

module "gcp_networking" {
  source = "../../modules/gcp-networking"
  
  project_id  = var.gcp_project_id
  region      = var.gcp_region
  environment = var.environment
}

module "gcp_bigquery" {
  source = "../../modules/gcp-bigquery"
  
  project_id    = var.gcp_project_id
  region        = var.gcp_region
  environment   = var.environment
  domains       = var.clinical_domains
  kms_key_id    = module.gcp_kms.key_id
  aws_role_arn  = module.aws_s3.bigquery_connection_role_arn
}

module "gcp_kms" {
  source = "../../modules/gcp-kms"
  
  project_id  = var.gcp_project_id
  region      = var.gcp_region
  environment = var.environment
}

module "gcp_composer" {
  source = "../../modules/gcp-composer"
  
  project_id   = var.gcp_project_id
  region       = var.gcp_region
  environment  = var.environment
  network      = module.gcp_networking.network_id
  subnetwork   = module.gcp_networking.subnetwork_id
  kms_key_id   = module.gcp_kms.key_id
}

module "gcp_governance" {
  source = "../../modules/gcp-governance"
  
  project_id  = var.gcp_project_id
  region      = var.gcp_region
  environment = var.environment
  domains     = var.clinical_domains
}

module "gcp_monitoring" {
  source = "../../modules/gcp-monitoring"
  
  project_id  = var.gcp_project_id
  region      = var.gcp_region
  environment = var.environment
  domains     = var.clinical_domains
}

module "aws_security_enhanced" {
  source = "../../modules/aws-security-enhanced"
  
  environment    = var.environment
  s3_bucket_name = module.aws_s3.bucket_name
  kms_key_id     = module.aws_kms.key_id
}

# Next-level enterprise modules
module "gcp_disaster_recovery" {
  source = "../../modules/gcp-disaster-recovery"
  
  project_id         = var.gcp_project_id
  primary_region     = var.gcp_region
  secondary_region   = var.gcp_dr_region
  environment        = var.environment
  domains            = var.clinical_domains
  bigquery_datasets  = module.gcp_bigquery.dataset_ids
  kms_key_id        = module.gcp_kms.key_id
}

module "gcp_streaming" {
  source = "../../modules/gcp-streaming"
  
  project_id  = var.gcp_project_id
  region      = var.gcp_region
  environment = var.environment
  domains     = var.clinical_domains
  network     = module.gcp_networking.network_id
  subnetwork  = module.gcp_networking.subnetwork_id
}

module "gcp_mlops" {
  source = "../../modules/gcp-mlops"
  
  project_id         = var.gcp_project_id
  region             = var.gcp_region
  environment        = var.environment
  domains            = var.clinical_domains
  bigquery_datasets  = module.gcp_bigquery.dataset_ids
  kms_key_id        = module.gcp_kms.key_id
}

module "gcp_lineage" {
  source = "../../modules/gcp-lineage"
  
  project_id  = var.gcp_project_id
  region      = var.gcp_region
  environment = var.environment
  domains     = var.clinical_domains
  kms_key_id  = module.gcp_kms.key_id
}

module "gcp_cost_optimization" {
  source = "../../modules/gcp-cost-optimization"
  
  project_id         = var.gcp_project_id
  region             = var.gcp_region
  environment        = var.environment
  domains            = var.clinical_domains
  billing_account_id = var.gcp_billing_account_id
}

module "aws_intelligent_tiering" {
  source = "../../modules/aws-intelligent-tiering"
  
  environment     = var.environment
  domains         = var.clinical_domains
  s3_bucket_name  = module.aws_s3.bucket_name
  kms_key_id      = module.aws_kms.key_id
}

# Output comprehensive information
output "infrastructure_summary" {
  description = "Comprehensive summary of deployed infrastructure"
  value = {
    aws = {
      s3_bucket           = module.aws_s3.bucket_name
      kms_key_id         = module.aws_kms.key_id
      security_hub       = module.aws_security_enhanced.security_hub_arn
      cost_reports       = module.aws_intelligent_tiering.cost_reports_bucket
      intelligent_tiering = module.aws_intelligent_tiering.intelligent_tiering_configs
    }
    gcp = {
      project_id         = var.gcp_project_id
      bigquery_datasets  = module.gcp_bigquery.dataset_ids
      composer_env       = module.gcp_composer.environment_name
      vpc_network        = module.gcp_networking.network_id
      kms_key_id        = module.gcp_kms.key_id
      monitoring        = module.gcp_monitoring.dashboard_urls
      disaster_recovery = {
        backup_datasets    = module.gcp_disaster_recovery.backup_datasets
        transfer_jobs     = module.gcp_disaster_recovery.transfer_job_names
        health_checks     = module.gcp_disaster_recovery.health_check_ids
      }
      streaming = {
        pubsub_topics     = module.gcp_streaming.pubsub_topics
        dataflow_jobs     = module.gcp_streaming.dataflow_jobs
        streaming_tables  = module.gcp_streaming.streaming_tables
      }
      mlops = {
        workbench         = module.gcp_mlops.workbench_instance
        model_endpoints   = module.gcp_mlops.model_endpoints
        featurestore      = module.gcp_mlops.featurestore_id
      }
      lineage = {
        lineage_topic     = module.gcp_lineage.lineage_topic
        lineage_dataset   = module.gcp_lineage.lineage_dataset
        atlas_cluster     = module.gcp_lineage.atlas_cluster
      }
      cost_optimization = {
        reservation       = module.gcp_cost_optimization.reservation_name
        analytics_dataset = module.gcp_cost_optimization.cost_analytics_dataset
        bi_reservation    = module.gcp_cost_optimization.bi_reservation_size
      }
    }
    data_governance = {
      taxonomy_id       = module.gcp_governance.taxonomy_id
      policy_tags       = module.gcp_governance.policy_tag_ids
    }
  }
}

output "data_mesh_endpoints" {
  description = "Key endpoints for data mesh access"
  value = {
    bigquery_datasets  = [for domain in var.clinical_domains : "${var.gcp_project_id}.${domain}_${var.environment}"]
    s3_ingestion      = "s3://${module.aws_s3.bucket_name}/"
    composer_ui       = module.gcp_composer.airflow_uri
    monitoring        = module.gcp_monitoring.dashboard_urls
    ml_workbench      = "https://console.cloud.google.com/vertex-ai/workbench/instances"
    lineage_ui        = "https://console.cloud.google.com/datacatalog"
  }
}

output "security_compliance" {
  description = "Security and compliance configuration"
  value = {
    encryption = {
      aws_kms_key = module.aws_kms.key_id
      gcp_kms_key = module.gcp_kms.key_id
    }
    vpc_service_controls = module.gcp_networking.service_perimeter_name
    security_monitoring = {
      aws_security_hub = module.aws_security_enhanced.security_hub_arn
      gcp_monitoring   = module.gcp_monitoring.alert_policy_ids
    }
    data_governance = {
      policy_tags      = module.gcp_governance.policy_tag_ids
      taxonomy         = module.gcp_governance.taxonomy_id
    }
  }
}

output "operational_tools" {
  description = "Operational and monitoring tools"
  value = {
    disaster_recovery = {
      backup_status    = "https://console.cloud.google.com/bigquery/scheduled-queries"
      health_checks    = module.gcp_disaster_recovery.health_check_ids
    }
    cost_optimization = {
      bigquery_slots   = module.gcp_cost_optimization.reservation_name
      s3_analytics     = module.aws_intelligent_tiering.analytics_bucket
      cost_reports     = module.aws_intelligent_tiering.cost_reports_bucket
    }
    streaming = {
      pubsub_console   = "https://console.cloud.google.com/cloudpubsub/topic/list"
      dataflow_console = "https://console.cloud.google.com/dataflow/jobs"
    }
    ml_operations = {
      vertex_ai        = "https://console.cloud.google.com/vertex-ai"
      model_registry   = "https://console.cloud.google.com/vertex-ai/models"
      feature_store    = "https://console.cloud.google.com/vertex-ai/feature-store"
    }
  }
}
