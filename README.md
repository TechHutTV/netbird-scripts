# netbird-scripts

Automation scripts for [Netbird](https://netbird.io/) deployment on Proxmox VE.

## Netbird LXC Container for Proxmox VE

Creates a Debian-based LXC container optimized for running Netbird.

### Quick Start

Run this command on your Proxmox VE host:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/TechHutTV/netbird-scripts/main/netbird-pve-lxc.sh)"
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

## Testing

Run the test suite directly from your Proxmox VE host:

```bash
git clone --depth 1 https://github.com/TechHutTV/netbird-scripts.git /tmp/netbird-scripts && /tmp/netbird-scripts/testing/run-tests.sh -v; rm -rf /tmp/netbird-scripts
```

See [testing/README.md](testing/README.md) for more details.

## License

GPL-3.0
