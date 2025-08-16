Infrastructure as Code (Terraform)

Structure

- modules/aws: S3 ingestion buckets, KMS, IAM role for BigQuery AWS Connection
- modules/gcp-bigquery: BigQuery datasets + AWS BigQuery Connection
- modules/gcp-composer: Cloud Composer environment
- modules/gcp-governance: Data Catalog taxonomy + policy tags
- envs/dev and envs/prod: Compose modules per environment
- sentinel-policies: Policy-as-code for HIPAA guardrails

Usage

- Use Terraform Cloud/Enterprise with OIDC; do not use local state.
- Configure workspace variables from env-specific `terraform.tfvars` (do not commit secrets).
- Attach Sentinel policies in Terraform Cloud Policy Sets.
