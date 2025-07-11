# Linux Mint Optimizer - Ansible Pull GitOps

A GitOps-based system optimization toolkit for Linux Mint using Ansible-Pull and systemd automation.

## Overview

This project implements a **pull-based GitOps approach** for managing Linux Mint system optimizations. Instead of pushing configurations to remote systems, each system autonomously pulls the latest configuration from this GitHub repository and applies it locally.

### Key Features

- **Disk Storage Optimization**: Reduces systemd journal and coredump storage from GBs to 500MB each
- **GitOps Automation**: Systems automatically sync and apply changes every 15 minutes
- **Ansible-Pull Architecture**: No SSH keys or central management server required
- **Systemd Integration**: Native Linux service management with proper logging

## Architecture

```
GitHub Repository → ansible-pull → Local Ansible → System Changes
       ↑                ↑              ↑              ↑
   Git commits      Systemd Timer   Local execution  File changes
```

### Ansible-Pull vs Traditional Ansible

**Traditional Ansible (Push)**:
- Central control node pushes to managed nodes
- Requires SSH access and key management
- Immediate execution from control node

**Ansible-Pull (Pull)**:
- Each node pulls from Git repository
- No SSH required, only Git access
- Autonomous execution via systemd timer
- Perfect for GitOps workflows

## Quick Setup

1. **Clone and customize** (optional):
   ```bash
   git clone https://github.com/norandom/linux-mint-optimizer.git
   cd linux-mint-optimizer
   # Modify roles/system_optimization/tasks/main.yml as needed
   ```

2. **Run setup script** on target system:
   ```bash
   sudo ./setup_ansible_user.sh
   # Enter your GitHub repository URL when prompted
   ```

3. **Verify operation**:
   ```bash
   # Check timer status
   systemctl status ansible-pull.timer
   
   # View logs
   journalctl -u ansible-pull.service -f
   
   # Manual test
   sudo -u ansible ansible-pull -U https://github.com/norandom/linux-mint-optimizer.git -i inventory/hosts.yml site.yml
   ```

## Project Structure

```
├── ansible.cfg                 # Ansible configuration
├── site.yml                   # Main playbook
├── setup_ansible_user.sh      # System preparation script
├── inventory/
│   └── hosts.yml              # Inventory for localhost
└── roles/
    └── system_optimization/
        ├── tasks/main.yml     # Optimization tasks
        └── handlers/main.yml  # Service restart handlers
```

## What Gets Optimized

| Component | Before | After | Configuration |
|-----------|--------|-------|---------------|
| systemd Journal | ~4GB+ | 500MB | `/etc/systemd/journald.conf` |
| Core Dumps | ~4GB+ | 500MB | `/etc/systemd/coredump.conf` |

## Systemd Integration

The setup creates two systemd units:

### ansible-pull.service
- **Type**: oneshot
- **User**: ansible (passwordless sudo)
- **Function**: Executes ansible-pull command
- **Trigger**: Called by timer or manually

### ansible-pull.timer
- **Schedule**: Every 15 minutes with 2-minute random delay
- **Boot delay**: 5 minutes after boot
- **Function**: Triggers the service automatically

### Timer Configuration
```ini
[Timer]
OnBootSec=5min           # Wait 5 minutes after boot
OnUnitActiveSec=15min    # Run every 15 minutes
RandomizedDelaySec=2min  # Add 0-2 minute random delay
```

## Adding More Systems

1. **Push-based management** (traditional):
   ```yaml
   # Add to inventory/hosts.yml
   all:
     hosts:
       mint-workstation-01:
         ansible_host: 192.168.1.100
         ansible_user: ansible
   ```

2. **Pull-based management** (GitOps):
   - Run `setup_ansible_user.sh` on each new system
   - Each system will independently pull and apply changes

## Customization

### Adding New Optimization Tasks

Edit `roles/system_optimization/tasks/main.yml`:

```yaml
- name: Your new optimization task
  lineinfile:
    path: /path/to/config
    regexp: '^#?Setting='
    line: 'Setting=value'
    backup: yes
  notify: restart service
```

### Changing Schedule

Modify the timer in `setup_ansible_user.sh`:

```ini
[Timer]
OnUnitActiveSec=30min    # Change to 30 minutes
```

## Monitoring

```bash
# Check next run time
systemctl list-timers ansible-pull.timer

# Follow logs in real-time
journalctl -u ansible-pull.service -f

# Check current disk usage
journalctl --disk-usage
du -sh /var/lib/systemd/coredump
```

## Security Considerations

- Ansible user has passwordless sudo (required for system changes)
- Service runs with `PrivateTmp=yes` for isolation
- No SSH keys required (Git-only access)
- All changes are logged via systemd journal

## Troubleshooting

### Service Fails
```bash
journalctl -u ansible-pull.service --no-pager -n 50
```

### Timer Not Running
```bash
systemctl status ansible-pull.timer
systemctl enable ansible-pull.timer
```

### Manual Testing
```bash
sudo -u ansible ansible-pull -U https://github.com/norandom/linux-mint-optimizer.git -i inventory/hosts.yml site.yml
```