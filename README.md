# Linux Mint Optimizer

Ansible roles that tune a Linux Mint VM for AI/ML workloads in Docker on KVM/libvirt. Each system pulls this repo on a timer and applies the playbook locally. No central control node, no SSH keys.

## What this is

A pull-based GitOps setup. Instead of a control node pushing config out, every host runs `ansible-pull` against this repo every 15 minutes and applies the playbook to itself.

Why pull instead of push:
- No SSH access or key management between a control node and the VMs.
- Each VM is autonomous. Bring up a new one, run the setup script, and it joins the fleet.
- Changes are git commits. Rollback is a revert.

```
GitHub repo  ->  ansible-pull (systemd timer)  ->  local Ansible run  ->  changes applied
```

## Quick setup

Clone the repo (optional, only needed if you want to customize):

```bash
git clone https://github.com/norandom/linux-mint-optimizer.git
cd linux-mint-optimizer
```

Run the setup script on the target system:

```bash
sudo ./setup_ansible_user.sh
# It will ask for your repo URL.
```

Verify:

```bash
systemctl status ansible-pull.timer
journalctl -u ansible-pull.service -f
sudo ansible-playbook -i inventory/hosts.yml site.yml
```

## Roles

The playbook runs these in order:

1. `system_optimization`: caps systemd journal and coredump storage at 500MB each.
2. `xrdp_setup`: installs xrdp on port 3389, ships keyboard maps and a startwm.sh that disables compositing/animations to save bandwidth.
3. `kvm_guest_optimization`: qemu-guest-agent, tuned `virtual-guest` profile, OpenSSH with root login enabled (see security note below), firewall rules for 22 and 3389.
4. `ai_performance_optimization`: irqbalance, ondemand CPU governor, sysctl tuning (`vm.swappiness=1`, overcommit on, NUMA balancing off), `mq-deadline` I/O scheduler, THP set to madvise.
5. `service_optimization`: disables bluetooth, cups, avahi-daemon, ModemManager, whoopsie, apport, kerneloops, fwupd. systemd-resolved stays on so DNS keeps working; the role tests `nslookup` after.
6. `advanced_performance`: GRUB cmdline gets `mitigations=off audit=0 elevator=mq-deadline transparent_hugepage=madvise intel_idle.max_cstate=1`. Also BBR + TCP Fast Open, noatime on root, deeper C-states disabled, and a Docker daemon.json with overlay2 + memlock unlimited.

## Expected gains

These are ballpark, not measured on your hardware. Memory-constrained VMs benefit the most.

| Category | Light | Heavy AI | Memory-constrained |
|---|---|---|---|
| Memory | 10-15% | 20-30% | 30-50% |
| CPU | 5-10% | 15-25% | 10-20% |
| I/O | 5-10% | 10-15% | 5-15% |
| Service cleanup | 5-10% | 10-15% | 15-25% |
| Advanced tuning | 10-15% | 20-30% | 25-40% |
| Combined | 15-25% | 30-50% | 40-70% |

If you actually want to know what it does on your workload, benchmark before and after.

## Running Docker AI containers

The Docker daemon gets configured for overlay2 with memlock unlimited. For a container:

```bash
docker run --shm-size=2g \
           --tmpfs /tmp:rw,size=1g,huge=always \
           --ulimit memlock=-1 \
           --cpus="4" \
           your-ai-container
```

## Project layout

```
ansible.cfg                # ansible config
site.yml                   # main playbook
setup_ansible_user.sh      # bootstrap script
inventory/hosts.yml        # localhost inventory
roles/
  system_optimization/
  xrdp_setup/
  kvm_guest_optimization/
  ai_performance_optimization/
  service_optimization/
  advanced_performance/
```

## What gets changed

| Component | Before | After | Where |
|---|---|---|---|
| systemd journal | ~4GB+ | 500MB | `/etc/systemd/journald.conf` |
| coredumps | ~4GB+ | 500MB | `/etc/systemd/coredump.conf` |
| swappiness | default | 1 | `/etc/sysctl.d/99-ai-performance.conf` |
| I/O scheduler | default | mq-deadline | runtime + GRUB |
| CPU governor | default | ondemand | `/etc/default/cpufrequtils` |
| Services | ~56 enabled | ~45 enabled | systemctl disable |
| CPU mitigations | on | off | GRUB `mitigations=off` |

## systemd units

The setup script writes two units:

- `ansible-pull.service`: oneshot, runs as the `ansible` user, calls `ansible-pull`.
- `ansible-pull.timer`: fires 5min after boot, then every 15min with a 0-2min random delay.

```ini
[Timer]
OnBootSec=5min
OnUnitActiveSec=15min
RandomizedDelaySec=2min
```

## Adding more hosts

Run `setup_ansible_user.sh` on each one. They will pull and apply independently.

For a one-off manual run:

```bash
sudo ansible-playbook -i inventory/hosts.yml site.yml
sudo ansible-playbook -i inventory/hosts.yml site.yml --check --diff   # dry run
```

## Monitoring

```bash
systemctl list-timers ansible-pull.timer
journalctl -u ansible-pull.service -f

journalctl --disk-usage
du -sh /var/lib/systemd/coredump

cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
systemctl list-units --type=service --state=running | wc -l
```

## Security notes

This setup trades security for performance and convenience. Do not run it on anything exposed to the public internet.

- `mitigations=off` disables Spectre/Meltdown CPU mitigations.
- `audit=0` turns off the kernel audit subsystem.
- SSH allows root login with passwords.
- The `ansible` user has passwordless sudo.

The assumption is that these VMs sit behind a firewall, are only reached from a trusted host network, and the cost of a compromised guest is bounded. If that is not your situation, do not deploy this as-is.

The xrdp role uses xrdp's bundled SSL certificate. That is fine on a trusted local network, not fine if anything reaches port 3389 from the internet. To replace it, generate your own and point xrdp.ini at it:

```bash
openssl req -x509 -newkey rsa:4096 -nodes -keyout key.pem -out cert.pem -days 365
```

The accepted-risk inventory for personal/lab use is in `Risks.md`.

## Troubleshooting

Service failed:

```bash
journalctl -u ansible-pull.service --no-pager -n 50
```

Timer not running:

```bash
systemctl status ansible-pull.timer
systemctl enable ansible-pull.timer
```

Manual verbose run:

```bash
sudo ansible-playbook -i inventory/hosts.yml site.yml -v
```

CPU not at expected speed:

```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
sudo cpufreq-set -g performance   # pin to performance instead of ondemand
```

## Reboot

Some changes need a reboot to take full effect: GRUB cmdline parameters, kernel parameter changes via sysctl that touch boot-time settings. Service changes apply immediately. After the first run, reboot once.

## CPU governor

Default is `ondemand`. For sustained AI workloads where you want maximum clock at the cost of power:

```bash
sudo cpufreq-set -g performance
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
```
