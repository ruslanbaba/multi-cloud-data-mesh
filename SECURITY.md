Security Policy

- No credentials in repo. Use OIDC to assume roles and Workload Identity Federation.
- All datasets and buckets use CMEK/KMS. Public access is denied by policy.
- Secrets managed via Google Secret Manager and AWS Secrets Manager; not in code.
- PRs must pass Sentinel policy checks and static scans (tfsec).
- Report security issues privately to the maintainers; do not open a public issue.
