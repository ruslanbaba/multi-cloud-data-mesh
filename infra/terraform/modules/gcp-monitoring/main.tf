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
variable "notification_channels" { type = list(string), default = [] }

# SLI/SLO definitions for data pipeline reliability
resource "google_monitoring_slo" "data_freshness" {
  service      = google_monitoring_service.data_mesh.service_id
  display_name = "Data Freshness SLO"
  
  request_based_sli {
    good_total_ratio {
      good_service_filter = "resource.type=\"bigquery_dataset\" metric.type=\"bigquery.googleapis.com/job/num_completed\" metric.label.job_type=\"QUERY\""
      total_service_filter = "resource.type=\"bigquery_dataset\" metric.type=\"bigquery.googleapis.com/job/num_in_flight\""
    }
  }
  
  goal = 0.99
  rolling_period = "2592000s" # 30 days
}

resource "google_monitoring_service" "data_mesh" {
  service_id   = "data-mesh-${var.environment}"
  display_name = "Data Mesh Service"
}

# Alert policies for critical components
resource "google_monitoring_alert_policy" "bigquery_job_failures" {
  display_name = "BigQuery Job Failures"
  combiner     = "OR"
  
  conditions {
    display_name = "BigQuery failed jobs"
    condition_threshold {
      filter          = "resource.type=\"bigquery_project\" metric.type=\"bigquery.googleapis.com/job/num_failed\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }
  
  notification_channels = var.notification_channels
  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_alert_policy" "composer_dag_failures" {
  display_name = "Composer DAG Failures"
  combiner     = "OR"
  
  conditions {
    display_name = "DAG task failures"
    condition_threshold {
      filter          = "resource.type=\"composer_environment\" metric.type=\"composer.googleapis.com/environment/dag_run/failed_count\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_DELTA"
      }
    }
  }
  
  notification_channels = var.notification_channels
}

# Data quality monitoring dashboard
resource "google_monitoring_dashboard" "data_quality" {
  dashboard_json = jsonencode({
    displayName = "Data Mesh Quality Dashboard"
    mosaicLayout = {
      tiles = [
        {
          width = 6
          height = 4
          widget = {
            title = "BigQuery Slot Utilization"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"bigquery_project\" metric.type=\"bigquery.googleapis.com/slots/allocated\""
                    aggregation = {
                      alignmentPeriod = "60s"
                      perSeriesAligner = "ALIGN_MEAN"
                    }
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Slots"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width = 6
          height = 4
          widget = {
            title = "dbt Test Results"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"k8s_container\" metric.type=\"logging.googleapis.com/user/dbt_test_passed\""
                  aggregation = {
                    alignmentPeriod = "300s"
                    perSeriesAligner = "ALIGN_SUM"
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_LINE"
              }
            }
          }
        }
      ]
    }
  })
}

# Custom metrics for data lineage and quality
resource "google_logging_metric" "data_lineage_events" {
  name   = "data_lineage_events"
  filter = "resource.type=\"bigquery_dataset\" jsonPayload.event_type=\"lineage_update\""
  
  metric_descriptor {
    metric_kind = "GAUGE"
    value_type  = "INT64"
    display_name = "Data Lineage Events"
  }
  
  value_extractor = "EXTRACT(jsonPayload.table_count)"
}

output "slo_name" { value = google_monitoring_slo.data_freshness.name }
output "dashboard_url" { value = "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.data_quality.id}" }
