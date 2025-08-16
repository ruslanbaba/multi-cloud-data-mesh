// DEPRECATED MODULE - DO NOT USE
// Composer is now provisioned via infra/terraform/modules/gcp-composer
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = { source = "hashicorp/google", version = ">= 5.31.1" }
  }
}

locals { noop = true }
