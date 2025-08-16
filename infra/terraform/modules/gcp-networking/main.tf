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
variable "environment" { type = string }
variable "region" { type = string }
variable "enable_vpc_sc" { type = bool, default = true }

# VPC Service Controls for data perimeter security
resource "google_access_context_manager_access_policy" "policy" {
  count  = var.enable_vpc_sc ? 1 : 0
  parent = "organizations/${data.google_project.current.org_id}"
  title  = "Data Mesh VPC-SC Policy ${var.environment}"
}

resource "google_access_context_manager_service_perimeter" "data_perimeter" {
  count  = var.enable_vpc_sc ? 1 : 0
  parent = google_access_context_manager_access_policy.policy[0].name
  name   = "accessPolicies/${google_access_context_manager_access_policy.policy[0].name}/servicePerimeters/datamesh-${var.environment}"
  title  = "Data Mesh Perimeter ${var.environment}"
  
  status {
    restricted_services = [
      "bigquery.googleapis.com",
      "storage.googleapis.com",
      "secretmanager.googleapis.com"
    ]
    resources = ["projects/${data.google_project.current.number}"]
    
    vpc_accessible_services {
      enable_restriction = true
      allowed_services = [
        "bigquery.googleapis.com",
        "storage.googleapis.com",
        "composer.googleapis.com"
      ]
    }
  }
}

# Private Service Connect for secure BigQuery access
resource "google_compute_global_address" "psc_endpoint" {
  name          = "bigquery-psc-${var.environment}"
  purpose       = "PRIVATE_SERVICE_CONNECT"
  network       = google_compute_network.vpc.id
  address_type  = "INTERNAL"
}

resource "google_compute_global_forwarding_rule" "psc_bigquery" {
  name                  = "bigquery-psc-${var.environment}"
  target                = "all-apis"
  port_range           = "443"
  ip_address           = google_compute_global_address.psc_endpoint.address
  network              = google_compute_network.vpc.id
  load_balancing_scheme = ""
}

# Dedicated VPC for data mesh
resource "google_compute_network" "vpc" {
  name                    = "datamesh-vpc-${var.environment}"
  auto_create_subnetworks = false
  routing_mode           = "REGIONAL"
}

resource "google_compute_subnetwork" "data_subnet" {
  name          = "data-subnet-${var.environment}"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
  
  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling       = 0.5
    metadata           = "INCLUDE_ALL_METADATA"
  }
  
  private_ip_google_access = true
}

# NAT Gateway for controlled internet access
resource "google_compute_router" "router" {
  name    = "datamesh-router-${var.environment}"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "datamesh-nat-${var.environment}"
  router                            = google_compute_router.router.name
  region                            = var.region
  nat_ip_allocate_option            = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

data "google_project" "current" {}

output "vpc_id" { value = google_compute_network.vpc.id }
output "subnet_id" { value = google_compute_subnetwork.data_subnet.id }
output "psc_endpoint" { value = google_compute_global_address.psc_endpoint.address }
