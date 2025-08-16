variable "project_id" { type = string }
variable "taxonomy_display_name" { type = string }

resource "google_data_catalog_taxonomy" "pii" {
  project      = var.project_id
  region       = "us"
  display_name = var.taxonomy_display_name
  activated_policy_types = ["FINE_GRAINED_ACCESS_CONTROL"]
}

resource "google_data_catalog_policy_tag" "phi" {
  taxonomy     = google_data_catalog_taxonomy.pii.name
  display_name = "PHI"
}

output "policy_tag_id" { value = google_data_catalog_policy_tag.phi.name }
