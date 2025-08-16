# Security Configuration Variables for Multi-Cloud Data Mesh

variable "notification_email" {
  description = "Email address for security alerts and notifications"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "Must be a valid email address."
  }
}

variable "github_owner" {
  description = "GitHub organization/owner for CI/CD pipelines"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$", var.github_owner))
    error_message = "GitHub owner must be a valid organization name."
  }
}

variable "github_repo" {
  description = "GitHub repository name for the data mesh project"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$", var.github_repo))
    error_message = "GitHub repository must be a valid repository name."
  }
}

variable "allowed_ml_users" {
  description = "List of authorized users for ML workbench access"
  type        = list(string)
  validation {
    condition = alltrue([
      for email in var.allowed_ml_users : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All users must have valid email addresses."
  }
}

variable "enable_audit_logging" {
  description = "Enable comprehensive audit logging across all services"
  type        = bool
  default     = true
}

variable "enable_vpc_service_controls" {
  description = "Enable VPC Service Controls for enhanced security"
  type        = bool
  default     = true
}

variable "enable_private_google_access" {
  description = "Enable Private Google Access for instances without external IPs"
  type        = bool
  default     = true
}

variable "allowed_ip_ranges" {
  description = "List of allowed IP ranges for secure access"
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  validation {
    condition = alltrue([
      for cidr in var.allowed_ip_ranges : can(cidrhost(cidr, 0))
    ])
    error_message = "All IP ranges must be valid CIDR blocks."
  }
}

variable "security_level" {
  description = "Security level for the environment"
  type        = string
  default     = "high"
  validation {
    condition     = contains(["low", "medium", "high", "critical"], var.security_level)
    error_message = "Security level must be one of: low, medium, high, critical."
  }
}

variable "compliance_requirements" {
  description = "Compliance requirements for the data mesh"
  type = object({
    hipaa_enabled = bool
    sox_enabled   = bool
    gdpr_enabled  = bool
    ccpa_enabled  = bool
  })
  default = {
    hipaa_enabled = true
    sox_enabled   = true
    gdpr_enabled  = true
    ccpa_enabled  = true
  }
}

variable "backup_retention_days" {
  description = "Data backup retention period in days"
  type        = number
  default     = 2555  # 7 years for HIPAA compliance
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 3650
    error_message = "Backup retention must be between 1 and 3650 days."
  }
}

variable "enable_encryption_at_rest" {
  description = "Enable encryption at rest for all data"
  type        = bool
  default     = true
}

variable "enable_encryption_in_transit" {
  description = "Enable encryption in transit for all data"
  type        = bool
  default     = true
}

variable "min_tls_version" {
  description = "Minimum TLS version for secure communications"
  type        = string
  default     = "1.3"
  validation {
    condition     = contains(["1.2", "1.3"], var.min_tls_version)
    error_message = "TLS version must be 1.2 or 1.3."
  }
}

variable "enable_vulnerability_scanning" {
  description = "Enable automated vulnerability scanning"
  type        = bool
  default     = true
}

variable "enable_intrusion_detection" {
  description = "Enable intrusion detection and prevention"
  type        = bool
  default     = true
}

variable "enable_data_loss_prevention" {
  description = "Enable Data Loss Prevention (DLP) scanning"
  type        = bool
  default     = true
}

variable "security_monitoring_retention_days" {
  description = "Security monitoring data retention in days"
  type        = number
  default     = 365
  validation {
    condition     = var.security_monitoring_retention_days >= 30 && var.security_monitoring_retention_days <= 3650
    error_message = "Security monitoring retention must be between 30 and 3650 days."
  }
}

variable "incident_response_email" {
  description = "Email address for incident response notifications"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.incident_response_email))
    error_message = "Must be a valid email address."
  }
}

variable "security_team_members" {
  description = "List of security team member email addresses"
  type        = list(string)
  validation {
    condition = alltrue([
      for email in var.security_team_members : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All security team members must have valid email addresses."
  }
}

variable "enable_secret_scanning" {
  description = "Enable secret scanning in repositories"
  type        = bool
  default     = true
}

variable "enable_dependency_scanning" {
  description = "Enable dependency vulnerability scanning"
  type        = bool
  default     = true
}

variable "enable_container_scanning" {
  description = "Enable container image vulnerability scanning"
  type        = bool
  default     = true
}

variable "max_failed_login_attempts" {
  description = "Maximum failed login attempts before account lockout"
  type        = number
  default     = 5
  validation {
    condition     = var.max_failed_login_attempts >= 3 && var.max_failed_login_attempts <= 10
    error_message = "Max failed login attempts must be between 3 and 10."
  }
}

variable "session_timeout_minutes" {
  description = "Session timeout in minutes for inactive users"
  type        = number
  default     = 30
  validation {
    condition     = var.session_timeout_minutes >= 5 && var.session_timeout_minutes <= 240
    error_message = "Session timeout must be between 5 and 240 minutes."
  }
}

variable "enable_mfa" {
  description = "Enable multi-factor authentication"
  type        = bool
  default     = true
}

variable "password_policy" {
  description = "Password policy configuration"
  type = object({
    min_length           = number
    require_uppercase    = bool
    require_lowercase    = bool
    require_numbers      = bool
    require_symbols      = bool
    max_age_days        = number
    prevent_reuse_count = number
  })
  default = {
    min_length           = 12
    require_uppercase    = true
    require_lowercase    = true
    require_numbers      = true
    require_symbols      = true
    max_age_days        = 90
    prevent_reuse_count = 12
  }
}

variable "network_security_groups" {
  description = "Network security group configurations"
  type = map(object({
    description = string
    ingress_rules = list(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
    }))
    egress_rules = list(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
    }))
  }))
  default = {}
}
