#!/bin/bash

# Bootstrap script for ansible-pull GitOps on Linux Mint.
# Creates the `ansible` user with passwordless sudo, installs ansible+git,
# then writes the systemd service + timer that pull this repo on a schedule.

set -e

echo "=== Linux Mint ansible-pull setup ==="

echo "apt update + upgrade..."
apt update && apt upgrade -y

echo "Installing ansible, git, python3 deps..."
apt install -y ansible git python3-pip python3-apt python3-setuptools sudo

if ! id "ansible" &>/dev/null; then
    echo "Creating ansible user..."
    useradd -m -s /bin/bash ansible
else
    echo "ansible user already exists, leaving it alone"
fi

echo "Adding ansible to the sudo group..."
usermod -aG sudo ansible

echo "Granting passwordless sudo..."
echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
chmod 440 /etc/sudoers.d/ansible

mkdir -p /home/ansible
chown ansible:ansible /home/ansible

mkdir -p /home/ansible/.ansible
chown ansible:ansible /home/ansible/.ansible

echo "=== systemd service ==="
read -p "Repo URL (e.g. https://github.com/username/linux-mint-optimizer.git): " REPO_URL

if [ -z "$REPO_URL" ]; then
    echo "No URL given. Aborting."
    exit 1
fi

echo "Writing /etc/systemd/system/ansible-pull.service..."
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

echo "Writing /etc/systemd/system/ansible-pull.timer..."
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

echo "Enabling the timer..."
systemctl daemon-reload
systemctl enable ansible-pull.timer
systemctl start ansible-pull.timer

echo "=== Done ==="
echo "Repo: $REPO_URL"
echo
echo "To check things:"
echo "  Manual run:    sudo -u ansible ansible-pull -U $REPO_URL -i inventory/hosts.yml site.yml"
echo "  Timer status:  systemctl status ansible-pull.timer"
echo "  Last run logs: journalctl -u ansible-pull.service"
echo "  Follow logs:   journalctl -f -u ansible-pull.service"