# Accepted Security Risks for Linux Mint Optimizer

This document outlines known security risks present in the `linux-mint-optimizer` project configurations. These risks are **consciously accepted by the user** for personal, isolated, and non-production environments where the primary goal is maximum performance, and the threat model does not include external attackers.

## Identified Risks:

### 1. High Risk: SSH Root Login with Passwords
*   **Location:** `roles/kvm_guest_optimization/tasks/main.yml`
*   **Description:** The configuration allows direct `root` login via SSH and enables password authentication for SSH. This is highly insecure as it makes the system vulnerable to brute-force attacks and compromises if the root password is weak or guessed.
*   **Mitigation (if not accepted):** Disable `PermitRootLogin` or set it to `prohibit-password`, and disable `PasswordAuthentication` in `/etc/ssh/sshd_config`, relying solely on SSH key-based authentication.

### 2. High Risk: CPU Security Mitigations Disabled
*   **Location:** `roles/advanced_performance/tasks/main.yml`
*   **Description:** The GRUB boot parameters include `mitigations=off`, which disables software mitigations for critical hardware vulnerabilities such as Spectre, Meltdown, and L1TF. While this significantly boosts performance, it leaves the system open to potential side-channel attacks and information disclosure.
*   **Mitigation (if not accepted):** Remove `mitigations=off` from `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`.

### 3. Medium Risk: Weakened Address Space Layout Randomization (ASLR)
*   **Location:** `roles/ai_performance_optimization/tasks/main.yml`
*   **Description:** The `kernel.randomize_va_space` sysctl parameter is set to `1`. This provides only conservative ASLR, disabling randomization for the data stack. Full ASLR (level `2`, the typical default) would randomize more memory regions, making memory-based exploits harder to achieve.
*   **Mitigation (if not accepted):** Set `vm.randomize_va_space` to `2` in `sysctl.d` configuration.

### 4. Medium Risk: Audit Logging Disabled
*   **Location:** `roles/advanced_performance/tasks/main.yml`
*   **Description:** The GRUB boot parameters include `audit=0`, which completely disables the kernel's auditing subsystem. This means that no logs will be generated for security-relevant events, making it difficult to detect or investigate security incidents.
*   **Mitigation (if not accepted):** Set `audit=1` in `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`.

### 5. Medium Risk: Firmware Updates Disabled
*   **Location:** `roles/service_optimization/tasks/main.yml`
*   **Description:** The `fwupd` service, responsible for firmware updates, is stopped and disabled. This prevents automatic or easy application of security patches for firmware components, potentially leaving hardware vulnerable.
*   **Mitigation (if not accepted):** Enable and start the `fwupd` service (`systemctl enable --now fwupd`). Regularly check for and apply firmware updates.

### 6. Architectural Risk: Passwordless Sudo for Ansible User
*   **Location:** `setup_ansible_user.sh`
*   **Description:** The `setup_ansible_user.sh` script configures the `ansible` user with passwordless `sudo` privileges (`ansible ALL=(ALL) NOPASSWD:ALL`). While necessary for the automated GitOps pull mechanism, this means any compromise of the `ansible` user or the Git repository it pulls from grants immediate root access to the system.
*   **Mitigation (if not accepted):** Ensure the Git repository is extremely well-secured. Consider alternative approaches like `sudoers` rules that restrict the commands `ansible` can run, or use a more granular privilege escalation method if full automation is not strictly required.
