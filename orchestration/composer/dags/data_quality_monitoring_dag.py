from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator
from airflow.providers.google.cloud.sensors.bigquery import BigQueryTableExistenceSensor
from airflow.operators.python import PythonOperator
import logging

# Data quality monitoring DAG with SLI/SLO tracking

default_args = {
    "owner": "data-platform",
    "depends_on_past": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}

def log_data_quality_metric(**context):
    """Log custom metrics for data quality monitoring"""
    table = context['params']['table']
    metric_value = context['ti'].xcom_pull(task_ids=f'quality_check_{table}')
    
    # Log structured data for Cloud Monitoring to pick up
    logging.info(f"data_quality_metric table={table} value={metric_value}")

with DAG(
    dag_id="data_quality_monitoring",
    default_args=default_args,
    start_date=datetime(2024, 1, 1),
    schedule_interval="@hourly",
    catchup=False,
    max_active_runs=1,
    tags=["monitoring", "sli", "data-quality"],
):
    
    # Data freshness SLI - check if data is updated within expected window
    freshness_check = BigQueryInsertJobOperator(
        task_id="data_freshness_sli",
        configuration={
            "query": {
                "query": """
                WITH freshness_check AS (
                  SELECT 
                    table_name,
                    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), last_modified_time, HOUR) as hours_since_update,
                    CASE 
                      WHEN TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), last_modified_time, HOUR) <= 2 THEN 1 
                      ELSE 0 
                    END as freshness_sli
                  FROM `{{ var.value.GCP_PROJECT_ID }}`.`region-us`.INFORMATION_SCHEMA.TABLE_STORAGE
                  WHERE table_schema LIKE '%_{{ var.value.ENV }}'
                )
                SELECT 
                  table_name,
                  hours_since_update,
                  freshness_sli,
                  CURRENT_TIMESTAMP() as check_timestamp
                FROM freshness_check
                """,
                "useLegacySql": False,
                "destinationTable": {
                    "projectId": "{{ var.value.GCP_PROJECT_ID }}",
                    "datasetId": "monitoring_{{ var.value.ENV }}",
                    "tableId": "data_freshness_sli"
                },
                "writeDisposition": "WRITE_APPEND"
            }
        },
    )
    
    # Data completeness SLI - check for expected row counts
    completeness_check = BigQueryInsertJobOperator(
        task_id="data_completeness_sli",
        configuration={
            "query": {
                "query": """
                WITH expected_counts AS (
                  SELECT 'admissions' as domain, 1000 as expected_min_rows
                  UNION ALL SELECT 'labs', 5000
                  UNION ALL SELECT 'pharmacy', 2000
                ),
                actual_counts AS (
                  SELECT 
                    REGEXP_EXTRACT(table_name, r'^(.+)_external$') as domain,
                    row_count
                  FROM `{{ var.value.GCP_PROJECT_ID }}`.`region-us`.INFORMATION_SCHEMA.TABLE_STORAGE
                  WHERE table_schema LIKE '%_{{ var.value.ENV }}'
                    AND table_name LIKE '%_external'
                )
                SELECT 
                  e.domain,
                  e.expected_min_rows,
                  COALESCE(a.row_count, 0) as actual_rows,
                  CASE 
                    WHEN COALESCE(a.row_count, 0) >= e.expected_min_rows THEN 1 
                    ELSE 0 
                  END as completeness_sli,
                  CURRENT_TIMESTAMP() as check_timestamp
                FROM expected_counts e
                LEFT JOIN actual_counts a ON e.domain = a.domain
                """,
                "useLegacySql": False,
                "destinationTable": {
                    "projectId": "{{ var.value.GCP_PROJECT_ID }}",
                    "datasetId": "monitoring_{{ var.value.ENV }}",
                    "tableId": "data_completeness_sli"
                },
                "writeDisposition": "WRITE_APPEND"
            }
        },
    )
    
    # Log metrics for Cloud Monitoring
    log_freshness_metric = PythonOperator(
        task_id="log_freshness_metric",
        python_callable=log_data_quality_metric,
        params={'table': 'freshness'}
    )
    
    log_completeness_metric = PythonOperator(
        task_id="log_completeness_metric", 
        python_callable=log_data_quality_metric,
        params={'table': 'completeness'}
    )
    
    freshness_check >> log_freshness_metric
    completeness_check >> log_completeness_metric
