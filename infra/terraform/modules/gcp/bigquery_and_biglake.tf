// DEPRECATED MODULE - DO NOT USE
// This legacy module has been replaced by:
//   - infra/terraform/modules/gcp-bigquery
//   - infra/terraform/modules/gcp-composer
// Keeping an inert file here to prevent accidental resource creation.
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = { source = "hashicorp/google", version = ">= 5.31.1" }
  }
}

locals {
  deprecation_notice = "Module deprecated. Use gcp-bigquery and gcp-composer."
}
