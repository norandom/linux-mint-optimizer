#!/bin/bash

# Script to prepare Linux Mint system for Ansible-Pull GitOps
# Creates ansible user with passwordless sudo and installs required packages

set -e

echo "=== Linux Mint Ansible-Pull Setup ==="

# Update system
echo "Updating system packages..."
apt update && apt upgrade -y

# Install required packages
echo "Installing required packages..."
apt install -y ansible git python3-pip python3-apt python3-setuptools sudo

# Create ansible user if it doesn't exist
if ! id "ansible" &>/dev/null; then
    echo "Creating ansible user..."
    useradd -m -s /bin/bash ansible
    echo "ansible user created successfully"
else
    echo "ansible user already exists"
fi

# Add ansible user to sudo group
echo "Adding ansible user to sudo group..."
usermod -aG sudo ansible

# Configure passwordless sudo for ansible user
echo "Configuring passwordless sudo for ansible user..."
echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
chmod 440 /etc/sudoers.d/ansible

# Create working directory for ansible user
echo "Setting up working directory for ansible user..."
mkdir -p /home/ansible
chown ansible:ansible /home/ansible

# Create ansible configuration directory
echo "Creating ansible configuration directory..."
mkdir -p /home/ansible/.ansible
chown ansible:ansible /home/ansible/.ansible

# Prompt for GitHub repository URL
echo "=== Systemd Service Setup ==="
read -p "Enter your GitHub repository URL (e.g., https://github.com/username/linux-mint-optimizer.git): " REPO_URL

if [ -z "$REPO_URL" ]; then
    echo "Error: Repository URL cannot be empty"
    exit 1
fi

# Create systemd service file
echo "Creating ansible-pull systemd service..."
cat > /etc/systemd/system/ansible-pull.service << EOF
[Unit]
Description=Ansible Pull GitOps for Linux Mint Optimization
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=ansible
WorkingDirectory=/home/ansible
ExecStart=/usr/bin/ansible-pull -U $REPO_URL -i inventory/hosts.yml site.yml
StandardOutput=journal
StandardError=journal
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF

# Create systemd timer file
echo "Creating ansible-pull systemd timer..."
cat > /etc/systemd/system/ansible-pull.timer << EOF
[Unit]
Description=Run Ansible Pull every 15 minutes
Requires=ansible-pull.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=15min
RandomizedDelaySec=2min

[Install]
WantedBy=timers.target
EOF

# Reload systemd and enable the timer
echo "Enabling and starting ansible-pull timer..."
systemctl daemon-reload
systemctl enable ansible-pull.timer
systemctl start ansible-pull.timer

echo "=== Setup completed successfully ==="
echo "Repository URL: $REPO_URL"
echo ""
echo "Next steps:"
echo "1. Test ansible-pull manually: sudo -u ansible ansible-pull -U $REPO_URL -i inventory/hosts.yml site.yml"
echo "2. Check timer status: systemctl status ansible-pull.timer"
echo "3. Check service logs: journalctl -u ansible-pull.service"
echo "4. Monitor next automatic run: journalctl -f -u ansible-pull.service"