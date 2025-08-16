from datetime import datetime
from airflow import DAG
from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator

# This DAG registers or updates external BigLake tables mapped to AWS S3 prefixes for each domain.
# The S3 paths are passed via Airflow Variables or Connections and should never include credentials.

DOMAINS = [
    "admissions", "labs", "pharmacy", "radiology", "vitals", "billing",
    "appointments", "allergies", "diagnoses", "procedures", "medications",
    "observations", "immunizations", "encounters", "claims", "registrations",
    "careplans", "devices", "providers", "patients",
]

with DAG(
    dag_id="biglake_register_external_tables",
    start_date=datetime(2024, 1, 1),
    schedule_interval=None,
    catchup=False,
    max_active_runs=1,
    tags=["biglake", "federation"],
):
    for domain in DOMAINS:
        # Airflow Variable expected: f"S3_URI_{domain.upper()}" -> e.g., s3://bucket/path/*
        s3_uri_var = f"S3_URI_{domain.upper()}"
        dataset = f"{domain}_dev"  # align with Terraform dataset naming in dev
        sql = f"""
        CREATE OR REPLACE EXTERNAL TABLE `{{ var.value.GCP_PROJECT_ID }}.{dataset}.{domain}_external`
        WITH CONNECTION `{{ var.value.BQ_AWS_CONNECTION }}`
        OPTIONS (
          format = 'PARQUET',
          uris = [ '{{ var.value.%s }}' ]
        )
        """ % s3_uri_var

        BigQueryInsertJobOperator(
            task_id=f"register_{domain}",
            configuration={
                "query": {
                    "query": sql,
                    "useLegacySql": False,
                }
            },
        )
