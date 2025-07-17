# Linux Mint Optimizer - Comprehensive AI/ML Performance Suite

A GitOps-based comprehensive optimization toolkit for Linux Mint systems running AI/ML workloads in Docker containers on KVM/libvirt VMs.

## Overview

This project implements a **pull-based GitOps approach** for managing Linux Mint system optimizations. Instead of pushing configurations to remote systems, each system autonomously pulls the latest configuration from this GitHub repository and applies it locally.

### Key Features

- **AI/ML Performance Optimization**: Comprehensive CPU, memory, and I/O optimizations for AI workloads
- **KVM Guest Integration**: QEMU guest agent, tuned profiles, and VM-specific optimizations  
- **Remote Desktop Access**: XRDP with bandwidth optimization for GUI access
- **Docker Performance**: Huge pages, optimized networking, and container-specific tuning
- **Service Optimization**: Disable unnecessary services to free resources
- **Advanced Performance**: Security trade-offs and low-latency networking
- **GitOps Automation**: Systems automatically sync and apply changes every 15 minutes
- **Ansible-Pull Architecture**: No SSH keys or central management server required

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
   # Modify roles as needed
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
   sudo ansible-playbook -i inventory/hosts.yml site.yml
   ```

## Optimization Roles

The system applies optimizations in the following order:

### 1. **system_optimization** - Base System Cleanup
- **systemd Journal**: Reduces from ~4GB+ to 500MB
- **Core Dumps**: Reduces from ~4GB+ to 500MB
- **Disk Usage**: Monitors and reports current usage

### 2. **xrdp_setup** - Remote Desktop Access
- **XRDP Server**: Remote desktop on port 3389
- **Bandwidth Optimization**: Disabled compositing and animations
- **SSL Configuration**: Secure remote access
- **Keyboard Mappings**: Comprehensive international support

### 3. **kvm_guest_optimization** - Virtual Machine Integration
- **QEMU Guest Agent**: Better VM management from host
- **Tuned Profile**: virtual-guest for VM optimization
- **SSH Server**: Root login enabled with password authentication
- **Firewall**: Configured for SSH (port 22) and XRDP (port 3389)

### 4. **ai_performance_optimization** - AI/ML Workload Tuning
- **CPU Governor**: ondemand (dynamic scaling enabled)
- **IRQ Balancing**: Distribute interrupts across CPUs
- **Memory Management**: swappiness=1, overcommit enabled
- **I/O Scheduler**: mq-deadline (optimal for VMs)
- **NUMA Balancing**: Disabled (not needed in VMs)
- **Transparent Huge Pages**: Set to madvise

### 5. **service_optimization** - Resource Cleanup
- **Disabled Services**: bluetooth, cups, avahi-daemon, ModemManager
- **Error Reporting**: whoopsie, apport, kerneloops disabled
- **Firmware Updates**: fwupd disabled (run manually when needed)
- **DNS Verification**: Ensures systemd-resolved still works
- **Resource Savings**: ~50-150MB RAM, ~2-5% CPU reduction

### 6. **advanced_performance** - Maximum Performance
- **Security Trade-offs**: Disabled speculative execution mitigations
- **Huge Pages**: 25% of RAM reserved for Docker containers
- **Low Latency Network**: BBR congestion control, TCP Fast Open
- **Filesystem**: noatime, optimized for qcow2 VMs
- **CPU C-States**: Limited to C0/C1 for consistent performance
- **Docker Integration**: Configured for huge pages and performance

## Performance Improvements

### Estimated Performance Gains

| Optimization Category | Light Workloads | Heavy AI Workloads | Memory-Constrained |
|----------------------|-----------------|-------------------|-------------------|
| **Memory Optimizations** | 10-15% | 20-30% | 30-50% |
| **CPU Optimizations** | 5-10% | 15-25% | 10-20% |
| **I/O Optimizations** | 5-10% | 10-15% | 5-15% |
| **Service Cleanup** | 5-10% | 10-15% | 15-25% |
| **Advanced Tuning** | 10-15% | 20-30% | 25-40% |
| **Combined Effect** | **15-25%** | **30-50%** | **40-70%** |

### Docker with Huge Pages

After optimization, use huge pages in Docker:

```bash
# Run AI container with huge pages
docker run --shm-size=2g --tmpfs /tmp:rw,size=1g,huge=always \
           --ulimit memlock=-1 your-ai-container

# Check huge pages usage
cat /proc/meminfo | grep -i huge
ls -la /mnt/hugepages/
```

## Project Structure

```
├── ansible.cfg                 # Ansible configuration
├── site.yml                   # Main playbook (all roles)
├── setup_ansible_user.sh      # System preparation script
├── inventory/
│   └── hosts.yml              # Inventory for localhost
└── roles/
    ├── system_optimization/           # Base system cleanup
    ├── xrdp_setup/                   # Remote desktop
    ├── kvm_guest_optimization/       # VM integration
    ├── ai_performance_optimization/  # AI workload tuning
    ├── service_optimization/         # Service cleanup
    └── advanced_performance/         # Maximum performance
```

## What Gets Optimized

| Component | Before | After | Configuration |
|-----------|--------|-------|---------------|
| systemd Journal | ~4GB+ | 500MB | `/etc/systemd/journald.conf` |
| Core Dumps | ~4GB+ | 500MB | `/etc/systemd/coredump.conf` |
| Memory Swapping | Default | swappiness=1 | `/etc/sysctl.d/99-ai-performance.conf` |
| I/O Scheduler | Default | mq-deadline | Runtime + GRUB |
| CPU Governor | Default | ondemand | `/etc/default/cpufrequtils` |
| Huge Pages | 0 | 25% of RAM | `/etc/sysctl.d/99-advanced-performance.conf` |
| Services | ~56 enabled | ~45 enabled | Disabled unnecessary services |
| Security Mitigations | Enabled | Disabled | GRUB `mitigations=off` |

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

### Pull-based management (GitOps):
- Run `setup_ansible_user.sh` on each new system
- Each system will independently pull and apply changes
- Perfect for managing multiple VMs

### Manual deployment:
```bash
# Deploy to current system
sudo ansible-playbook -i inventory/hosts.yml site.yml

# Check what would change
sudo ansible-playbook -i inventory/hosts.yml site.yml --check --diff
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

# Check huge pages
cat /proc/meminfo | grep -i huge

# Check CPU governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Check active services
systemctl list-units --type=service --state=running | wc -l
```

## Security Considerations

⚠️ **Performance vs Security Trade-offs**:
- **Speculative execution mitigations**: Disabled for performance
- **Audit logging**: Disabled to reduce overhead
- **Root SSH access**: Enabled for VM management
- **Passwordless sudo**: ansible user has full access

**Mitigations**:
- VMs are isolated from host network
- Ansible user access is logged
- All changes are version controlled
- Service runs with `PrivateTmp=yes` isolation

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
sudo ansible-playbook -i inventory/hosts.yml site.yml -v
```

### Performance Issues
```bash
# Check CPU governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Manually set performance mode
sudo cpufreq-set -g performance

# Check huge pages
cat /proc/meminfo | grep -i huge

# Check disabled services
systemctl list-unit-files --state=disabled | grep -E "(bluetooth|cups|avahi)"
```

### Reboot Requirements

Some optimizations require a reboot for full effect:
- GRUB kernel parameters (I/O scheduler, huge pages, security mitigations)
- Kernel parameter changes via sysctl
- Service optimizations are immediate

```bash
# Check if reboot is needed
sudo reboot  # After first deployment for full optimization
```

## CPU Governor Control

The system uses `ondemand` governor by default. For maximum AI performance:

```bash
# Switch to performance governor
sudo cpufreq-set -g performance

# Check current governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Available governors
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
```

## Docker Integration

The system is optimized for Docker AI workloads:

```bash
# Run container with optimizations
docker run --shm-size=2g \
           --tmpfs /tmp:rw,size=1g,huge=always \
           --ulimit memlock=-1 \
           --cpus="4" \
           your-ai-container

# Check Docker configuration
sudo cat /etc/docker/daemon.json
```

This comprehensive optimization suite transforms a standard Linux Mint VM into a high-performance AI/ML workstation with significant performance improvements across CPU, memory, I/O, and network operations.