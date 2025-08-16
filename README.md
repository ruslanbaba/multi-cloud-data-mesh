# Multi-Cloud Data Mesh: GCP BigQuery + AWS S3 (Enterprise Blueprint)

This repository is a production-grade blueprint for a multi-cloud data mesh where:

- AWS S3 is the ingestion landing zone per clinical domain.
- GCP BigQuery (with BigLake) is the central analytics warehouse.
- Federated queries read external data in S3 using a secure BigQuery AWS Connection.
- Transformations are implemented with dbt and orchestrated by Cloud Composer (Airflow).
- HIPAA safeguards are enforced with Terraform modules and Sentinel policies.
- CI/CD uses OIDC-based, keyless deployments with built-in security scanning.

Repository layout

- infra/terraform – IaC for AWS, GCP, and governance
	- modules/aws – S3 ingestion buckets, KMS, IAM role for BigQuery connection
	- modules/gcp – BigQuery datasets, BigLake connection, Composer, KMS, Data Catalog tags
	- envs/{dev,prod} – Environment compositions using the modules
	- sentinel-policies – Policy-as-code (HIPAA-oriented guardrails)
- dbt – dbt project (models, tests, macros). No credentials checked in.
- orchestration/composer – Airflow DAGs and requirements for Cloud Composer
- .github/workflows – CI/CD and security scans using OIDC (keyless)

Security by default

- No hard-coded credentials. OIDC between GitHub⇄GCP/AWS; Workload Identity on GCP.
- CMEK for BigQuery datasets and Composer; AWS KMS for S3 buckets.
- S3 public access blocked, versioning and server access logs on; TLS-only enforced.
- Data Catalog tag templates for PHI/PII classification; Policy Tags for column-level security.


Getting started (safe defaults)

1) Review placeholders in `infra/terraform/envs/dev/terraform.tfvars` (project IDs, regions, account IDs). Do not add secrets.
2) Use Terraform Cloud (or Enterprise) for state and policy checks. Connect VCS and OIDC to cloud providers.
3) Apply `dev` first, validate, then promote to `prod` with identical modules and stricter policies.

CI/CD secrets required (GitHub Actions)

- GCP_WORKLOAD_IDENTITY_PROVIDER: Full resource name of the Workload Identity Provider.
- GCP_TERRAFORM_SA: Terraform deploy service account email.
- AWS_TERRAFORM_ROLE_ARN: AWS IAM role ARN to assume for Terraform.
- GCP_DBT_SA: Service account email used by dbt CI to compile.
- GCP_PROJECT_ID: Project ID for dbt CI compile.

Airflow Variables expected

- ENV: dev or prod
- GCP_PROJECT_ID: Target GCP project for BigQuery
- BQ_AWS_CONNECTION: Connection ID created by Terraform (see output `connection_id`)
- One S3 URI per domain: S3_URI_ADMISSIONS, S3_URI_LABS, ..., S3_URI_PATIENTS

Column-level security with Data Catalog Policy Tags

- Terraform governance module creates a taxonomy and PHI policy tag; capture the output ID.
- dbt macro `apply_policy_tags` can set policy tags on columns post-model build.
- Example model `marts/patient_360_policy_tag.sql` applies a PHI tag to `patient_id` when env var `PHI_POLICY_TAG_ID` is provided.

dbt tests

- Staging tests: not_null, relationships, accepted_values (example LOINC codes) in `dbt/tests`.
- Add more accepted_values rules as standards are finalized; `dbt_utils` package is included.

dbt

- Adapter: `dbt-bigquery`.
- Auth: Application Default Credentials (ADC) via Composer service account; no local creds.
- Sources mirror 20 clinical domains. Staging models standardize schemas; marts aggregate.

Composer

- `dbt_orchestration_dag.py` runs dbt deps/run/test in Composer.
- `biglake_register_external_tables_dag.py` idempotently manages external table definitions.

Sentinel

- Enforces encryption, denies public S3, requires versioning+logging, and mandates tags.

