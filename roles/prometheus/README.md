<p align="center">
  <a href="https://digitalis.io">
    <img src="https://cdn.prod.website-files.com/68370d67a3c849c28c22f703/68370d67a3c849c28c22f803_digitalis-logo.svg" alt="Digitalis.IO" width="300">
  </a>
</p>

<p align="center">
  <em>Built and maintained by <a href="https://digitalis.io">Digitalis.IO</a></em>
</p>

---

# Ansible Role for Prometheus

Ansible role to install and configure [Prometheus](https://prometheus.io/) monitoring system.

Based on the [prometheus-community/ansible](https://github.com/prometheus-community/ansible) collection patterns with additional features and hardening.

## Requirements

- Ansible >= 2.15
- Supported platforms:
  - Rocky Linux 9, 10
  - Ubuntu 22.04, 24.04
  - Debian 12, 13
- Target must have systemd-based init system
- Controller must have internet access to download the Prometheus release from GitHub

## Role Variables

All variables are defined in `defaults/main.yml` with sensible defaults. Full argument specs are in `meta/argument_specs.yml`.

### Installation

| Variable | Default | Description |
|----------|---------|-------------|
| `prometheus_version` | `3.4.1` | Prometheus release version. Set to `latest` for auto-discovery |
| `prometheus_binary_url` | *(auto-generated)* | Override for mirrors or air-gapped installs |
| `prometheus_checksums_url` | *(auto-generated)* | SHA256 checksums URL. Set to `""` to skip verification |
| `prometheus_system_user` | `prometheus` | System user to run Prometheus |
| `prometheus_system_group` | `prometheus` | System group for Prometheus |
| `prometheus_db_dir` | `/var/lib/prometheus` | Data directory |
| `prometheus_config_dir` | `/etc/prometheus` | Configuration directory |
| `prometheus_binary_install_dir` | `/usr/local/bin` | Directory for binaries |
| `prometheus_local_cache_path` | `/tmp/prometheus-...` | Local cache for downloaded archive |

### Network

| Variable | Default | Description |
|----------|---------|-------------|
| `prometheus_web_listen_address` | `0.0.0.0:9090` | Address and port to listen on |
| `prometheus_web_external_url` | `""` | External URL for link generation (e.g., behind reverse proxy) |
| `prometheus_metrics_path` | `/metrics` | Metrics endpoint path |

### Web Config (TLS & Auth)

| Variable | Default | Description |
|----------|---------|-------------|
| `prometheus_web_config` | `{tls_server_config: {}, http_server_config: {}, basic_auth_users: {}}` | [Web configuration](https://github.com/prometheus/exporter-toolkit/blob/master/docs/web-configuration.md) for TLS and basic auth |

### Storage

| Variable | Default | Description |
|----------|---------|-------------|
| `prometheus_storage_retention` | `30d` | How long to keep data |
| `prometheus_storage_retention_size` | `0` | Maximum size of data (e.g., `50GB`) |

### Agent Mode

| Variable | Default | Description |
|----------|---------|-------------|
| `prometheus_agent_mode` | `false` | Enable [agent mode](https://prometheus.io/blog/2021/11/16/agent/) (disables querying/alerting, optimises for remote write) |

### Global Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `prometheus_global` | `{scrape_interval: 15s, scrape_timeout: 10s, evaluation_interval: 15s}` | Global Prometheus configuration |
| `prometheus_external_labels` | `{environment: "{{ ansible_fqdn }}"}` | Labels attached to all time series |

### Alerting

| Variable | Default | Description |
|----------|---------|-------------|
| `prometheus_alertmanager_config` | `[]` | Alertmanager targets configuration |
| `prometheus_alert_relabel_configs` | `[]` | Alert relabeling rules |
| `prometheus_alert_rules` | `[]` | Alerting rules (deployed to `rules/ansible_managed.yml`) |
| `prometheus_alert_rules_files` | `[prometheus/rules/*.yml, ...]` | Paths to custom alert rule files |

### Scrape Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `prometheus_scrape_configs` | *(self + node)* | List of scrape job configurations |
| `prometheus_scrape_config_files` | `[prometheus/scrape_configs/*.yml, ...]` | Custom scrape config files (v2.43.0+) |
| `prometheus_config_file` | `prometheus.yml.j2` | Alternative config template |

### File-Based Service Discovery

| Variable | Default | Description |
|----------|---------|-------------|
| `prometheus_targets` | `{}` | Dict of targets written to `file_sd/<key>.yml` |
| `prometheus_static_targets_files` | `[prometheus/targets/*.yml, ...]` | Paths to custom static target files |

### Remote Storage

| Variable | Default | Description |
|----------|---------|-------------|
| `prometheus_remote_write` | `[]` | Remote write configuration |
| `prometheus_remote_read` | `[]` | Remote read configuration |

### Service

| Variable | Default | Description |
|----------|---------|-------------|
| `prometheus_stop_timeout` | `600s` | Systemd TimeoutStopSec |
| `prometheus_config_flags_extra` | `{}` | Additional CLI flags as dict (e.g., `{alertmanager.timeout: 10s}`) |
| `prometheus_read_only_dirs` | `[]` | Additional read-only paths for systemd (e.g., SSL cert dirs) |
| `prometheus_enable_service` | `true` | Whether to start and enable the service. Set to `false` for image builds |

## Example Playbook

### Minimal

```yaml
- hosts: monitoring
  roles:
    - role: digitalis.digitalis.prometheus
```

### With scrape targets and file-based service discovery

```yaml
- hosts: monitoring
  roles:
    - role: digitalis.digitalis.prometheus
      vars:
        prometheus_storage_retention: 15d
        prometheus_external_labels:
          environment: production
          region: eu-west-1
        prometheus_targets:
          node:
            - targets:
                - "web01:9100"
                - "web02:9100"
                - "db01:9100"
              labels:
                team: platform
        prometheus_scrape_configs:
          - job_name: prometheus
            metrics_path: /metrics
            static_configs:
              - targets:
                  - "localhost:9090"
          - job_name: node
            file_sd_configs:
              - files:
                  - "/etc/prometheus/file_sd/node.yml"
```

### With remote write (e.g., to Thanos or Mimir)

```yaml
- hosts: monitoring
  roles:
    - role: digitalis.digitalis.prometheus
      vars:
        prometheus_remote_write:
          - url: "http://mimir:9009/api/v1/push"
            queue_config:
              max_samples_per_send: 1000
              batch_send_deadline: 5s
```

### Agent mode (remote write only)

```yaml
- hosts: monitoring
  roles:
    - role: digitalis.digitalis.prometheus
      vars:
        prometheus_agent_mode: true
        prometheus_remote_write:
          - url: "http://mimir:9009/api/v1/push"
```

### With TLS and basic auth

```yaml
- hosts: monitoring
  roles:
    - role: digitalis.digitalis.prometheus
      vars:
        prometheus_web_config:
          tls_server_config:
            cert_file: /etc/prometheus/tls.crt
            key_file: /etc/prometheus/tls.key
          http_server_config: {}
          basic_auth_users:
            admin: $2y$10$...  # bcrypt hash
```

### With alerting rules

```yaml
- hosts: monitoring
  roles:
    - role: digitalis.digitalis.prometheus
      vars:
        prometheus_alertmanager_config:
          - static_configs:
              - targets:
                  - "127.0.0.1:9093"
        prometheus_alert_rules:
          - alert: InstanceDown
            expr: "up == 0"
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "{% raw %}Instance {{ $labels.instance }} down{% endraw %}"
```

### Latest version auto-discovery

```yaml
- hosts: monitoring
  roles:
    - role: digitalis.digitalis.prometheus
      vars:
        prometheus_version: latest
```

## Architecture Support

This role automatically detects the target architecture:
- `amd64` (x86_64)
- `arm64` (aarch64)
- `armv7` (armv7l)
- `armv6` (armv6l)

## Systemd Hardening

The systemd unit includes security hardening directives:
- `NoNewPrivileges`, `PrivateDevices`, `PrivateTmp`, `ProtectHome`
- `MemoryDenyWriteExecute`, `LockPersonality`, `RemoveIPC`, `RestrictSUIDSGID`
- `ProtectSystem=strict` (systemd 232+), `PrivateUsers`, `ProtectKernelModules/Tunables`
- `ReadWritePaths` restricted to data directory only

## Tags

Use tags for selective execution:
- `prometheus_install` — download and install binaries only
- `prometheus_configure` — configuration, rules, targets, and service unit
- `prometheus_run` — service management only

## Testing

This role uses [Molecule](https://molecule.readthedocs.io/) with the Docker driver for testing.

```bash
# Run full test suite
molecule test

# Test on a specific platform
MOLECULE_IMAGE=geerlingguy/docker-rockylinux9-ansible molecule test
```

Tested platforms:
- Rocky Linux 9, 10
- Ubuntu 22.04, 24.04
- Debian 12, 13

## Need Help?

If you need assistance with this role, Prometheus monitoring, or any infrastructure automation challenges, we're here to help.

[Get in touch with us](https://digitalis.io/contact-us) — our team of infrastructure experts can help you with deployment, scaling, and ongoing operations.

## License

Apache-2.0

## Author Information

[Digitalis.IO](https://digitalis.io/) — Cloud-native infrastructure experts.
