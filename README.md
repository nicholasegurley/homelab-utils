# Homelab Utilities

A collection of useful utilities for homelab environments, particularly focused on Proxmox VE management and automation.

## Overview

This repository contains various scripts and tools designed to help manage and maintain homelab infrastructure. Each utility is designed to be simple, reliable, and well-documented.

## Utilities

### Proxmox Backup Script (`proxmox-backup.sh`)

A comprehensive backup solution for Proxmox VE hosts that creates timestamped archives of critical configuration files and directories.

#### Features

- **Comprehensive Coverage**: Backs up essential Proxmox configuration files including:
  - Proxmox cluster configuration (`/etc/pve`)
  - Network configuration (`/etc/network/interfaces`)
  - System files (`/etc/hosts`, `/etc/hostname`, `/etc/passwd`, etc.)
  - SSH configuration (`/etc/ssh`)
  - Cron jobs (`/etc/cron*`)
  - APT package management (`/etc/apt`)
  - User home directories (`/root`)
  - Cluster data (`/var/lib/pve-cluster`)

- **Smart Mount Detection**: Verifies that the backup destination is on a mounted filesystem (ideal for NFS storage)

- **Automatic Retention**: Configurable retention policy (default: 30 days) with automatic cleanup of old backups

- **Flexible Destination**: Customizable backup destination with sensible defaults

#### Usage

```bash
# Use default destination (/root/proxmox-backups)
./proxmox-backup.sh

# Specify custom destination
./proxmox-backup.sh /mnt/backup-storage/proxmox-backups
```

#### Configuration

- **Default Destination**: `/root/proxmox-backups`
- **Retention Period**: 30 days (configurable via `RETENTION_DAYS` variable)
- **Backup Format**: Compressed tar.gz archives with timestamp naming

#### Requirements

- Proxmox VE host
- Write access to destination directory
- Destination must be on a mounted filesystem (not root filesystem)

#### Safety Features

- Mount point validation to prevent filling up the root filesystem
- Error handling with clear status messages
- Atomic backup creation with rollback on failure

#### Installation

1. Clone this repository to your Proxmox host:
   ```bash
   git clone <repository-url> /opt/homelab-utils
   cd /opt/homelab-utils
   ```

2. Make scripts executable:
   ```bash
   chmod +x *.sh
   ```

3. (Optional) Add to your PATH or create symlinks for easy access

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for:

- New utility scripts
- Improvements to existing utilities
- Bug fixes
- Documentation enhancements

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

These utilities are provided as-is for educational and homelab use. Always test thoroughly in your environment before relying on them for critical operations. The authors are not responsible for any data loss or system issues that may occur from using these tools.
