# netbird-scripts

Automation scripts for [Netbird](https://netbird.io/) deployment on Proxmox VE.

## Netbird LXC Container for Proxmox VE

Creates a Debian-based LXC container optimized for running Netbird.

### Quick Start

Run this command on your Proxmox VE host:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/TechHutTV/netbird-scripts/main/netbird-pve-lxc.sh)"
```

Or using wget:

```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/TechHutTV/netbird-scripts/main/netbird-pve-lxc.sh)"
```

### Default Container Specs

| Setting | Default |
|---------|---------|
| OS | Debian 13 (Trixie) / Debian 12 fallback |
| Storage | 8 GB |
| RAM | 512 MB |
| CPU | 1 core |
| Network | DHCP |
| Type | Unprivileged |

### Requirements

- Proxmox VE host
- Root access
- Internet connection (for template download)

## License

GPL-3.0