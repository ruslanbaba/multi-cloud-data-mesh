Cloud Composer Orchestration

DAGs

- dbt_orchestration_dag.py – Runs dbt deps/run/test on a schedule. Expects ENV Airflow Variable (dev|prod) and dbt project synced to /home/airflow/gcs/data/dbt.
- biglake_register_external_tables_dag.py – Idempotently creates/updates external BigLake tables per domain using AWS S3 URIs provided as Airflow Variables.

Required Airflow Variables

- ENV: dev or prod (default dev)
- GCP_PROJECT_ID: GCP project hosting BigQuery
- BQ_AWS_CONNECTION: BigQuery connection ID (e.g., location.aws_s3_dev)
- S3_URI_<DOMAIN>: S3 URI for each domain (e.g., S3_URI_ADMISSIONS = s3://bucket/admissions/*)

Security

- No credentials in DAGs. Access to S3 is via the BigQuery AWS Connection assuming an AWS IAM role.
- Composer service account must have BigQuery User and run permissions. Composer is CMEK-enabled via Terraform.
