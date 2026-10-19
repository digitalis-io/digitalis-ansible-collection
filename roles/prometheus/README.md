<p align="center">
  <a href="https://digitalis.io">
    <img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/DigitalisDigital_DigitalisFullLogoGradient+-+medium.png" alt="Digitalis.IO" width="300">
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
- The target downloads the release from GitHub by default. Set `prometheus_download_local: true` when the target has no internet access; the controller then downloads and copies it (see [examples/prometheus-offline](../../examples/prometheus-offline/playbook.yml))

## Quick Start

```bash
ansible-galaxy collection install digitalis.digitalis
```

```yaml
- hosts: monitoring
  become: true
  roles:
    - role: digitalis.digitalis.prometheus
```

```bash
ansible-playbook -i inventory site.yml
```

## Role Variables

Generated from `meta/argument_specs.yml`; run `scripts/generate-docs.sh` to refresh.

<!-- BEGIN_ANSIBLE_DOCS -->

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `prometheus_version` | str | no | `3.13.4` | Prometheus package version. Also accepts `latest` as parameter. |
| `prometheus_binary_url` | str | no | `https://github.com/{{ _prometheus_repo }}/releases/download/v{{ prometheus_version }}/prometheus-{{ prometheus_version }}.{{ ansible_facts['system'] \| lower }}-{{ _prometheus_go_ansible_arch }}.tar.gz` | URL of the Prometheus binaries .tar.gz file |
| `prometheus_checksums_url` | str | no | `https://github.com/{{ _prometheus_repo }}/releases/download/v{{ prometheus_version }}/sha256sums.txt` | URL of the Prometheus checksums file |
| `prometheus_config_dir` | str | no | `/etc/prometheus` | Path to directory with Prometheus configuration |
| `prometheus_db_dir` | str | no | `/var/lib/prometheus` | Path to directory with Prometheus database |
| `prometheus_read_only_dirs` | list of str | no | `[]` | Additional paths that Prometheus is allowed to read (useful for SSL certs outside of the config directory) |
| `prometheus_binary_install_dir` | str | no | `/usr/local/bin` | Directory to install binaries |
| `prometheus_web_listen_address` | str | no | `0.0.0.0:9090` | Address on which Prometheus will listen |
| `prometheus_web_config` | dict | no | `{"tls_server_config": {}, "http_server_config": {}, "basic_auth_users": {}}` | A Prometheus web config yaml for configuring TLS and auth. |
| `prometheus_web_external_url` | str | no | `""` | External address on which Prometheus is available. Useful when behind reverse proxy. |
| `prometheus_metrics_path` | str | no | `/{{ (prometheus_web_external_url + '/metrics') \| regex_replace('^(.*://)?(.*?)/') }}` | Prometheus external metrics path |
| `prometheus_storage_retention` | str | no | `30d` | Data retention period |
| `prometheus_storage_retention_size` | str | no | `0` | Data retention size limit. Maximum number of bytes that can be stored for blocks. Units supported: KB, MB, GB, TB, PB. |
| `prometheus_agent_mode` | bool | no | `false` | The Agent mode optimises Prometheus for the remote write use case. It disables querying, alerting, and local storage. |
| `prometheus_config_flags_extra` | dict | no | `{}` | Additional configuration flags passed to prometheus binary at startup. Example: prometheus_config_flags_extra: { alertmanager.timeout: 10s } |
| `prometheus_alertmanager_config` | list of dict | no | `[]` | Alertmanager configuration entries written to the `alerting.alertmanagers` section, for example `static_configs`. |
| `prometheus_alert_relabel_configs` | list of dict | no | `[]` | Alert relabeling rules as a list in YAML format. |
| `prometheus_global` | dict | no | `{"scrape_interval": "15s", "scrape_timeout": "10s", "evaluation_interval": "15s"}` | Prometheus global config. |
| `prometheus_remote_write` | list of dict | no | `[]` | Remote write endpoints. Each item needs `url`; see the Prometheus `remote_write` configuration for the other keys. |
| `prometheus_remote_read` | list of dict | no | `[]` | Remote read endpoints. Each item needs `url`; see the Prometheus `remote_read` configuration for the other keys. |
| `prometheus_external_labels` | dict | no | `{"environment": "{{ ansible_fqdn \| default(ansible_host) \| default(inventory_hostname) }}"}` | Additional labels added to all time series and alerts when communicating with external systems |
| `prometheus_targets` | dict | no | `{}` | Targets which will be scraped via file-based service discovery. |
| `prometheus_scrape_configs` | list of dict | no |  | Prometheus scrape job configurations. Defaults to a `prometheus` job scraping the local server and a `node` job reading targets from `file_sd/node.yml`. |
| `prometheus_config_file` | str | no | `prometheus.yml.j2` | Custom prometheus configuration file template |
| `prometheus_alert_rules` | list of dict | no | `[]` | List of alerting rules deployed to rules/ansible_managed.yml. |
| `prometheus_alert_rules_files` | list of str | no | `['prometheus/rules/*.yml', 'prometheus/rules/*.yaml']` | Paths to custom alerting rule files (globs). |
| `prometheus_static_targets_files` | list of str | no | `['prometheus/targets/*.yml', 'prometheus/targets/*.json']` | Paths to custom static target files (copied to file_sd/). |
| `prometheus_scrape_config_files` | list of str | no | `['prometheus/scrape_configs/*.yml', 'prometheus/scrape_configs/*.json']` | Paths to custom scrape config files (v2.43.0+). |
| `prometheus_system_group` | str | no | `prometheus` | System group for Prometheus. |
| `prometheus_system_user` | str | no | `prometheus` | System user for Prometheus. |
| `prometheus_stop_timeout` | str | no | `600s` | How long to wait for Prometheus to shutdown (systemd TimeoutStopSec). |
| `prometheus_enable_service` | bool | no | `true` | Whether to start and enable the Prometheus service. Set to false for image builds. |
| `prometheus_download_local` | bool | no | `false` | Download and verify the archive on the Ansible controller and copy it to the target (`true`, for targets without internet access), or download it on the target (`false`) |
| `prometheus_local_cache_path` | str | no | `/tmp/prometheus-{{ ansible_facts['system'] \| lower }}-{{ _prometheus_go_ansible_arch }}/{{ prometheus_version }}` | Path to cache the downloaded archive, on the host that downloads it |
<!-- END_ANSIBLE_DOCS -->

## Example Playbook

### Minimal

```yaml
- hosts: monitoring
  become: true
  roles:
    - role: digitalis.digitalis.prometheus
```

### With scrape targets and file-based service discovery

```yaml
- hosts: monitoring
  become: true
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
  become: true
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
  become: true
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
  become: true
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
  become: true
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
  become: true
  roles:
    - role: digitalis.digitalis.prometheus
      vars:
        prometheus_version: latest
```

See also the complete playbook in [examples/prometheus-remote-write](../../examples/prometheus-remote-write/playbook.yml) and [examples/prometheus-offline](../../examples/prometheus-offline/playbook.yml).

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

This project is maintained by [Digitalis.io](https://digitalis.io). For support, visit [digitalis.io/contact](https://digitalis.io/contact).

## License

Apache-2.0
