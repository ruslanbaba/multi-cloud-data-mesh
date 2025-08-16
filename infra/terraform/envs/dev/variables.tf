variable "project" { type = string }
variable "environment" { type = string }
variable "domains" { type = list(string) }

variable "terraform_cloud_organization" {
  description = "Terraform Cloud organization name"
  type        = string
}

variable "gcp_project_id" { type = string }
variable "gcp_location" { type = string }
variable "gcp_kms_key" { type = string }

variable "aws_region" { type = string }
variable "aws_bucket_prefix" { type = string }
variable "aws_log_bucket" { type = string }
variable "bigquery_connection_principal_arn" { type = string }

variable "composer_image_version" { type = string }
variable "composer_service_account" { type = string }
variable "vpc_network" { type = string }
variable "vpc_subnetwork" { type = string }
variable "taxonomy_display_name" { type = string }
