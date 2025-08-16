#!/bin/bash
# Secure startup script for ML Workbench
# Environment: ${environment}

set -euo pipefail

# Security: Set secure umask
umask 0027

# Security: Update system packages
apt-get update && apt-get upgrade -y

# Security: Install security tools
apt-get install -y \
    fail2ban \
    ufw \
    aide \
    rkhunter \
    chkrootkit \
    clamav \
    clamav-daemon

# Security: Configure firewall
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 8080  # Jupyter notebook

# Security: Configure fail2ban
systemctl enable fail2ban
systemctl start fail2ban

# Security: Set up intrusion detection
aide --init
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Security: Configure antivirus
freshclam
systemctl enable clamav-daemon
systemctl start clamav-daemon

# Security: Harden SSH (if SSH is needed)
if [ -f /etc/ssh/sshd_config ]; then
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/#Protocol 2/Protocol 2/' /etc/ssh/sshd_config
    systemctl restart ssh
fi

# Security: Set up log monitoring
cat > /etc/rsyslog.d/50-ml-security.conf << 'EOF'
# Security logging for ML workbench
auth,authpriv.*                 /var/log/auth.log
*.*;auth,authpriv.none          /var/log/syslog
EOF

systemctl restart rsyslog

# Security: Install and configure Google Cloud Security Command Center agent
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install

# Security: Set up file integrity monitoring
cat > /etc/aide/aide.conf.d/ml-workbench << 'EOF'
# ML Workbench specific monitoring
/opt/deeplearning f+p+u+g+s+m+c+md5+sha256
/home/jupyter f+p+u+g+s+m+c+md5+sha256
/etc f+p+u+g+s+m+c+md5+sha256
EOF

# Security: Set up automated security scans
cat > /etc/cron.daily/ml-security-scan << 'EOF'
#!/bin/bash
# Daily security scan for ML workbench

# File integrity check
aide --check

# Rootkit scan
rkhunter --check --sk

# Virus scan of critical directories
clamscan -r /home/jupyter /opt/deeplearning --infected --remove

# Log security events
logger "ML Workbench security scan completed"
EOF

chmod +x /etc/cron.daily/ml-security-scan

# Security: Configure kernel parameters
cat >> /etc/sysctl.conf << 'EOF'
# Security hardening
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
EOF

sysctl -p

# Security: Set up audit logging
if [ "${environment}" = "prod" ]; then
    apt-get install -y auditd
    cat > /etc/audit/rules.d/ml-workbench.rules << 'EOF'
# Audit rules for ML workbench
-w /home/jupyter -p wa -k jupyter_access
-w /opt/deeplearning -p wa -k ml_framework_access
-w /etc/passwd -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/sudoers -p wa -k sudoers_changes
EOF
    systemctl enable auditd
    systemctl start auditd
fi

# Security: Configure Jupyter security
if [ -f /opt/deeplearning/bin/jupyter ]; then
    # Generate secure Jupyter config
    /opt/deeplearning/bin/jupyter notebook --generate-config --allow-root
    
    # Set security options
    cat >> ~/.jupyter/jupyter_notebook_config.py << 'EOF'
# Security configuration
c.NotebookApp.ip = '127.0.0.1'
c.NotebookApp.open_browser = False
c.NotebookApp.token = ''
c.NotebookApp.disable_check_xsrf = False
c.NotebookApp.allow_root = True
c.NotebookApp.allow_remote_access = True
c.NotebookApp.cookie_secret_file = '/home/jupyter/.jupyter/cookie_secret'
c.NotebookApp.keyfile = '/home/jupyter/.jupyter/server.key'
c.NotebookApp.certfile = '/home/jupyter/.jupyter/server.crt'
EOF
fi

# Security: Log successful startup
logger "ML Workbench secure startup completed for environment: ${environment}"

# Security: Final system hardening
chmod 600 /etc/ssh/ssh_host_*_key
chmod 644 /etc/ssh/ssh_host_*_key.pub

echo "Secure ML Workbench startup completed successfully"
