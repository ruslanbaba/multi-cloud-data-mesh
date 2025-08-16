# Security Configuration Quick Reference

## Environment Variable Templates

### Development Environment (`dev/terraform.tfvars`)
```hcl
# Core Configuration
project = "healthcare-data-mesh-dev"
environment = "dev"
terraform_cloud_organization = "your-terraform-cloud-org"

# GCP Configuration
gcp_project_id = "healthcare-mesh-dev-12345"
gcp_location = "us-central1"
gcp_kms_key = "projects/healthcare-mesh-dev-12345/locations/us-central1/keyRings/healthcare-ring/cryptoKeys/healthcare-key"

# AWS Configuration  
aws_region = "us-east-1"
aws_bucket_prefix = "healthcare-dev"
aws_log_bucket = "healthcare-dev-audit-logs"

# Security Notifications
notification_email = "devops@your-healthcare-org.com"
security_contact_email = "security@your-healthcare-org.com"

# Network Security
enable_vpc_flow_logs = true
enable_private_clusters = true
authorized_networks = ["10.0.0.0/8", "172.16.0.0/12"]

# Compliance Settings
enable_hipaa_compliance = true
enable_audit_logging = true
data_retention_days = 2555  # 7 years for healthcare
```

### Production Environment (`prod/terraform.tfvars`)
```hcl
# Core Configuration
project = "healthcare-data-mesh-prod"
environment = "prod"
terraform_cloud_organization = "your-terraform-cloud-org"

# GCP Configuration
gcp_project_id = "healthcare-mesh-prod-67890"
gcp_location = "us-central1"
gcp_kms_key = "projects/healthcare-mesh-prod-67890/locations/us-central1/keyRings/healthcare-ring/cryptoKeys/healthcare-key"

# AWS Configuration
aws_region = "us-east-1" 
aws_bucket_prefix = "healthcare-prod"
aws_log_bucket = "healthcare-prod-audit-logs"

# Security Notifications
notification_email = "production-ops@your-healthcare-org.com"
security_contact_email = "security@your-healthcare-org.com"

# Network Security
enable_vpc_flow_logs = true
enable_private_clusters = true
authorized_networks = ["10.0.0.0/24"]  # More restrictive in prod

# Compliance Settings
enable_hipaa_compliance = true
enable_audit_logging = true
data_retention_days = 2555  # 7 years for healthcare
backup_retention_days = 365
```

## Security Checklist

### Pre-Deployment Security Validation

#### ✅ Credentials & Secrets
- [ ] No hard-coded passwords or API keys
- [ ] All email addresses parameterized
- [ ] No placeholder values (CHANGE_ME, TODO, etc.)
- [ ] KMS keys properly configured
- [ ] Service account keys rotated

#### ✅ IAM & Permissions
- [ ] Custom IAM roles with least privilege
- [ ] No unnecessary admin permissions
- [ ] Service accounts properly scoped
- [ ] Workload Identity enabled for GKE
- [ ] Time-based access controls configured

#### ✅ Network Security
- [ ] Private clusters enabled
- [ ] VPC isolation configured
- [ ] Authorized networks restricted
- [ ] Public access prevention enforced
- [ ] TLS/HTTPS enforced everywhere

#### ✅ Data Protection
- [ ] CMEK encryption enabled
- [ ] Data classification labels applied
- [ ] Backup encryption configured
- [ ] Data retention policies set
- [ ] DLP policies activated

#### ✅ Monitoring & Alerting
- [ ] Security monitoring enabled
- [ ] Audit logging configured
- [ ] Alert policies created
- [ ] Notification channels set up
- [ ] Log retention configured

#### ✅ Compliance
- [ ] HIPAA controls implemented
- [ ] SOX compliance verified
- [ ] GDPR requirements met
- [ ] Audit trails enabled
- [ ] Documentation updated

## Security Command Reference

### Validation Commands
```bash
# Check for security issues
terraform validate
terraform plan -var-file="terraform.tfvars"

# Security scanning
tfsec .
checkov -f terraform/

# Credential scanning
git secrets --scan
truffleHog --regex --entropy=False .
```

### Emergency Security Procedures

#### Credential Compromise Response
1. **Immediate Actions:**
   ```bash
   # Rotate all service account keys
   gcloud iam service-accounts keys create new-key.json --iam-account=SA_EMAIL
   gcloud iam service-accounts keys delete OLD_KEY_ID --iam-account=SA_EMAIL
   
   # Update KMS keys
   gcloud kms keys create new-key --location=LOCATION --keyring=RING --purpose=encryption
   ```

2. **Audit Actions:**
   ```bash
   # Check access logs
   gcloud logging read "protoPayload.authenticationInfo.principalEmail=COMPROMISED_EMAIL"
   
   # Review IAM changes
   gcloud logging read "protoPayload.serviceName=iam.googleapis.com"
   ```

#### Security Incident Response
1. **Isolation:**
   - Disable compromised service accounts
   - Apply network security policies
   - Enable emergency access controls

2. **Investigation:**
   - Review audit logs
   - Check data access patterns
   - Identify affected resources

3. **Recovery:**
   - Restore from secure backups
   - Update security configurations
   - Implement additional controls

## Contact Information

### Security Team Contacts
- **Security Lead:** security-lead@your-healthcare-org.com
- **Compliance Officer:** compliance@your-healthcare-org.com
- **DevOps Security:** devops-security@your-healthcare-org.com
- **24/7 Security Hotline:** +1-800-SECURITY

### Escalation Matrix
1. **Level 1:** DevOps Team (Response: < 4 hours)
2. **Level 2:** Security Team (Response: < 2 hours)
3. **Level 3:** CISO/Executive (Response: < 1 hour)
4. **Level 4:** External Security Firm (Response: < 30 minutes)

---
**Document Version:** 1.0
**Last Updated:** $(date)
**Next Review:** $(date -d "+90 days")
