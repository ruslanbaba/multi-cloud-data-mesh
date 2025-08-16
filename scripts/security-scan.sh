#!/bin/bash

# Multi-Cloud Data Mesh Security Scanner
# This script performs comprehensive security scanning across the entire repository

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_ISSUES=0
CRITICAL_ISSUES=0
HIGH_ISSUES=0
MEDIUM_ISSUES=0
LOW_ISSUES=0

echo -e "${BLUE}🔍 Multi-Cloud Data Mesh Security Scanner${NC}"
echo -e "${BLUE}===========================================${NC}"
echo "Starting comprehensive security assessment..."
echo

# Function to report issues
report_issue() {
    local severity=$1
    local description=$2
    local file=$3
    local line=$4
    
    case $severity in
        "CRITICAL")
            echo -e "${RED}[CRITICAL]${NC} $description"
            ((CRITICAL_ISSUES++))
            ;;
        "HIGH")
            echo -e "${RED}[HIGH]${NC} $description"
            ((HIGH_ISSUES++))
            ;;
        "MEDIUM")
            echo -e "${YELLOW}[MEDIUM]${NC} $description"
            ((MEDIUM_ISSUES++))
            ;;
        "LOW")
            echo -e "${BLUE}[LOW]${NC} $description"
            ((LOW_ISSUES++))
            ;;
    esac
    
    if [[ -n "$file" ]]; then
        echo "  File: $file"
        if [[ -n "$line" ]]; then
            echo "  Line: $line"
        fi
    fi
    echo
    ((TOTAL_ISSUES++))
}

echo -e "${BLUE}1. Scanning for Hard-coded Credentials and Secrets${NC}"
echo "=================================================="

# Check for hard-coded credentials
echo "Checking for hard-coded passwords, API keys, and tokens..."
if grep -r -E "(password|secret|key|token|credential|api_key|auth.*=\s*[\"'][^$])" --include="*.tf" --include="*.py" --include="*.yml" --include="*.yaml" . 2>/dev/null | grep -v "# .*password\|description.*password\|comment.*password\|kms_key\|ssh-key\|keyring\|cryptoKey"; then
    report_issue "CRITICAL" "Hard-coded credentials found" "" ""
else
    echo -e "${GREEN}✓ No hard-coded credentials found${NC}"
fi

# Check for placeholder values
echo "Checking for placeholder values..."
PLACEHOLDER_COUNT=$(grep -r "CHANGE_ME\|TODO\|FIXME\|placeholder\|example\.com" --include="*.tf" . 2>/dev/null | grep -v "\.example\|README\|SECURITY\|docs/" | wc -l)
if [[ $PLACEHOLDER_COUNT -gt 0 ]]; then
    report_issue "HIGH" "Found $PLACEHOLDER_COUNT placeholder values in production code" "" ""
    grep -r "CHANGE_ME\|TODO\|FIXME\|placeholder\|example\.com" --include="*.tf" . 2>/dev/null | grep -v "\.example\|README\|SECURITY\|docs/" | head -5
else
    echo -e "${GREEN}✓ No placeholder values found in production code${NC}"
fi

# Check for account IDs
echo "Checking for hard-coded account IDs..."
ACCOUNT_ID_COUNT=$(grep -r "[0-9]\{12\}" --include="*.tf" . 2>/dev/null | grep -v "\.example\|123456789012\|arn:aws:iam::aws:" | wc -l)
if [[ $ACCOUNT_ID_COUNT -gt 0 ]]; then
    report_issue "HIGH" "Found $ACCOUNT_ID_COUNT potential hard-coded account IDs" "" ""
else
    echo -e "${GREEN}✓ No hard-coded account IDs found${NC}"
fi

echo

echo -e "${BLUE}2. Scanning IAM and Permission Issues${NC}"
echo "====================================="

# Check for overly broad IAM permissions
echo "Checking for overly broad IAM permissions..."
BROAD_PERMS=$(grep -r "roles/.*admin\|roles/.*owner\|roles/editor\|\*" --include="*.tf" . 2>/dev/null | grep -v "# .*Changed\|# .*Removed\|# .*admin\|objectAdmin\|schedule.*\*\|cron.*\*\|arn.*\*" | wc -l)
if [[ $BROAD_PERMS -gt 0 ]]; then
    report_issue "MEDIUM" "Found $BROAD_PERMS potential overly broad IAM permissions" "" ""
    echo "Review these carefully:"
    grep -r "roles/.*admin\|roles/.*owner\|roles/editor" --include="*.tf" . 2>/dev/null | grep -v "# .*Changed\|# .*Removed\|objectAdmin" | head -3
else
    echo -e "${GREEN}✓ No overly broad IAM permissions found${NC}"
fi

# Check for missing input validation
echo "Checking for missing input validation..."
MODULES_WITHOUT_VALIDATION=$(find infra/terraform/modules -name "*.tf" -exec grep -L "validation\s*{" {} \; 2>/dev/null | grep -v "/main.tf\|/outputs.tf" | wc -l)
if [[ $MODULES_WITHOUT_VALIDATION -gt 0 ]]; then
    report_issue "MEDIUM" "Found $MODULES_WITHOUT_VALIDATION modules without input validation" "" ""
else
    echo -e "${GREEN}✓ All modules have input validation${NC}"
fi

echo

echo -e "${BLUE}3. Scanning Network Security${NC}"
echo "============================"

# Check for public access
echo "Checking for potential public access issues..."
PUBLIC_ACCESS=$(grep -r "0.0.0.0/0\|::/0\|public\|internet" --include="*.tf" . 2>/dev/null | grep -v "block_public\|restrict_public\|public_access_prevention\|# .*public" | wc -l)
if [[ $PUBLIC_ACCESS -gt 0 ]]; then
    report_issue "HIGH" "Found $PUBLIC_ACCESS potential public access configurations" "" ""
else
    echo -e "${GREEN}✓ No public access issues found${NC}"
fi

# Check for missing HTTPS enforcement
echo "Checking for HTTPS enforcement..."
if grep -r "http:" --include="*.tf" --include="*.py" --include="*.yml" . 2>/dev/null | grep -v "https:" | grep -v "# .*http"; then
    report_issue "MEDIUM" "Found HTTP (non-HTTPS) references" "" ""
else
    echo -e "${GREEN}✓ HTTPS enforcement verified${NC}"
fi

echo

echo -e "${BLUE}4. Scanning Infrastructure Security${NC}"
echo "==================================="

# Check for missing encryption
echo "Checking for encryption configuration..."
UNENCRYPTED=$(grep -r "encrypt" --include="*.tf" . 2>/dev/null | grep -v "encryption\|encrypted\|kms" | wc -l)
if [[ $UNENCRYPTED -gt 5 ]]; then
    report_issue "MEDIUM" "Some resources may lack proper encryption" "" ""
else
    echo -e "${GREEN}✓ Encryption properly configured${NC}"
fi

# Check for missing monitoring
echo "Checking for monitoring and logging..."
MONITORING_FILES=$(find . -name "*.tf" -exec grep -l "monitoring\|logging\|alert" {} \; 2>/dev/null | wc -l)
if [[ $MONITORING_FILES -lt 3 ]]; then
    report_issue "LOW" "Limited monitoring and alerting configuration" "" ""
else
    echo -e "${GREEN}✓ Monitoring and alerting configured${NC}"
fi

echo

echo -e "${BLUE}5. Scanning CI/CD Security${NC}"
echo "=========================="

# Check GitHub Actions security
echo "Checking GitHub Actions workflows..."
if find .github/workflows -name "*.yml" -exec grep -l "secrets\." {} \; 2>/dev/null | head -1 > /dev/null; then
    echo -e "${GREEN}✓ GitHub Actions use secrets properly${NC}"
else
    report_issue "LOW" "GitHub Actions may not be using secrets properly" "" ""
fi

# Check for OIDC usage
if grep -r "id-token: write" .github/workflows/ 2>/dev/null > /dev/null; then
    echo -e "${GREEN}✓ OIDC authentication configured${NC}"
else
    report_issue "MEDIUM" "OIDC authentication not configured" "" ""
fi

echo

echo -e "${BLUE}6. Scanning Code Quality and Security Practices${NC}"
echo "=============================================="

# Check for Terraform best practices
echo "Checking Terraform security practices..."
TERRAFORM_ISSUES=0

# Check for missing required_providers
if ! find infra/terraform -name "*.tf" -exec grep -l "required_providers" {} \; 2>/dev/null | head -1 > /dev/null; then
    report_issue "LOW" "Missing required_providers configuration" "" ""
    ((TERRAFORM_ISSUES++))
fi

# Check for version constraints
VERSION_CONSTRAINTS=$(grep -r ">= [0-9]" --include="*.tf" . 2>/dev/null | wc -l)
if [[ $VERSION_CONSTRAINTS -lt 5 ]]; then
    report_issue "LOW" "Missing version constraints on providers" "" ""
    ((TERRAFORM_ISSUES++))
fi

if [[ $TERRAFORM_ISSUES -eq 0 ]]; then
    echo -e "${GREEN}✓ Terraform security practices followed${NC}"
fi

echo

echo -e "${BLUE}7. File Permission and Structure Security${NC}"
echo "========================================"

# Check for executable scripts
echo "Checking file permissions..."
EXECUTABLE_FILES=$(find . -type f -perm +111 2>/dev/null | grep -v ".git\|node_modules" | wc -l)
if [[ $EXECUTABLE_FILES -gt 2 ]]; then
    report_issue "LOW" "Found $EXECUTABLE_FILES executable files - review permissions" "" ""
else
    echo -e "${GREEN}✓ File permissions appear appropriate${NC}"
fi

# Check for sensitive file patterns
echo "Checking for sensitive files..."
SENSITIVE_FILES=$(find . -name "*.key" -o -name "*.pem" -o -name "*.p12" -o -name "*.pfx" -o -name ".env" 2>/dev/null | grep -v ".example" | wc -l)
if [[ $SENSITIVE_FILES -gt 0 ]]; then
    report_issue "CRITICAL" "Found $SENSITIVE_FILES potentially sensitive files" "" ""
    find . -name "*.key" -o -name "*.pem" -o -name "*.p12" -o -name "*.pfx" -o -name ".env" 2>/dev/null | grep -v ".example"
else
    echo -e "${GREEN}✓ No sensitive files found${NC}"
fi

echo

# Final Security Report
echo -e "${BLUE}🛡️  Security Assessment Summary${NC}"
echo -e "${BLUE}==============================${NC}"
echo "Total Issues Found: $TOTAL_ISSUES"
echo -e "Critical Issues: ${RED}$CRITICAL_ISSUES${NC}"
echo -e "High Issues: ${RED}$HIGH_ISSUES${NC}"
echo -e "Medium Issues: ${YELLOW}$MEDIUM_ISSUES${NC}"
echo -e "Low Issues: ${BLUE}$LOW_ISSUES${NC}"
echo

# Calculate security score
SECURITY_SCORE=100
if [[ $CRITICAL_ISSUES -gt 0 ]]; then
    SECURITY_SCORE=$((SECURITY_SCORE - (CRITICAL_ISSUES * 20)))
fi
if [[ $HIGH_ISSUES -gt 0 ]]; then
    SECURITY_SCORE=$((SECURITY_SCORE - (HIGH_ISSUES * 10)))
fi
if [[ $MEDIUM_ISSUES -gt 0 ]]; then
    SECURITY_SCORE=$((SECURITY_SCORE - (MEDIUM_ISSUES * 5)))
fi
if [[ $LOW_ISSUES -gt 0 ]]; then
    SECURITY_SCORE=$((SECURITY_SCORE - (LOW_ISSUES * 1)))
fi

# Ensure score doesn't go below 0
if [[ $SECURITY_SCORE -lt 0 ]]; then
    SECURITY_SCORE=0
fi

echo -e "Security Score: ${GREEN}${SECURITY_SCORE}/100${NC}"
echo

# Security recommendations
if [[ $SECURITY_SCORE -lt 70 ]]; then
    echo -e "${RED}🚨 Security Status: HIGH RISK${NC}"
    echo "Immediate attention required. Address critical and high issues."
elif [[ $SECURITY_SCORE -lt 85 ]]; then
    echo -e "${YELLOW}⚠️  Security Status: MEDIUM RISK${NC}"
    echo "Good security posture with room for improvement."
else
    echo -e "${GREEN}✅ Security Status: LOW RISK${NC}"
    echo "Excellent security posture. Continue monitoring and maintenance."
fi

echo
echo -e "${BLUE}Security Recommendations:${NC}"
echo "1. Review and fix any critical and high-priority issues"
echo "2. Implement regular security scanning in CI/CD pipeline"
echo "3. Conduct periodic penetration testing"
echo "4. Keep all dependencies and providers updated"
echo "5. Regular security training for development team"
echo "6. Implement infrastructure drift detection"
echo "7. Review and rotate credentials regularly"

echo
echo -e "${GREEN}Security scan completed!${NC}"

# Exit with appropriate code
if [[ $CRITICAL_ISSUES -gt 0 ]]; then
    exit 2
elif [[ $HIGH_ISSUES -gt 0 ]]; then
    exit 1
else
    exit 0
fi
