terraform {
  required_version = ">= 1.6.0"
  backend "remote" {
    organization = "CHANGE_ME_TFC_ORG"
    workspaces { name = "multi-cloud-data-mesh-prod" }
  }
  required_providers {
    google = { source = "hashicorp/google" version = ">= 5.31.1" }
    google-beta = { source = "hashicorp/google-beta" version = ">= 5.31.1" }
    aws = { source = "hashicorp/aws" version = ">= 5.35.0" }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_location
}
provider "google-beta" {
  project = var.gcp_project_id
  region  = var.gcp_location
}
provider "aws" {
  region = var.aws_region
}

module "aws_ingestion" {
  source                  = "../../modules/aws"
  project                 = var.project
  environment             = var.environment
  region                  = var.aws_region
  domains                 = var.domains
  bucket_name_prefix      = var.aws_bucket_prefix
  log_bucket_name         = var.aws_log_bucket
  bigquery_connection_principal_arn = var.bigquery_connection_principal_arn
}

module "gcp_bq" {
  source      = "../../modules/gcp-bigquery"
  project_id  = var.gcp_project_id
  location    = var.gcp_location
  environment = var.environment
  domains     = var.domains
  kms_key_name = var.gcp_kms_key
  aws_role_arn = module.aws_ingestion.bigquery_connection_role_arn
}

module "composer" {
  source                   = "../../modules/gcp-composer"
  project_id               = var.gcp_project_id
  location                 = var.gcp_location
  environment              = var.environment
  image_version            = var.composer_image_version
  composer_service_account = var.composer_service_account
  network                  = var.vpc_network
  subnetwork               = var.vpc_subnetwork
  kms_key_name             = var.gcp_kms_key
}

module "governance" {
  source                 = "../../modules/gcp-governance"
  project_id             = var.gcp_project_id
  taxonomy_display_name  = var.taxonomy_display_name
}
