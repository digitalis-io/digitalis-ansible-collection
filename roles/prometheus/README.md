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
| `prometheus_version` | str | no | `3.13.4` | Prometheus version to install, for example `3.13.4`, or `latest` to resolve the newest GitHub release at run time (requires access to `api.github.com`; `GITHUB_TOKEN` from the controller environment is sent if set). Used in the default download URLs and cache path, and to choose version-dependent behaviour: retention flags (2.7.0), `--web.config.file` (2.24.0), `scrape_config_files` (2.43.0), agent flag and console files (3.0.0). Changing it downloads the new archive, replaces the binaries and restarts the service. |
| `prometheus_binary_url` | str | no | `https://github.com/{{ _prometheus_repo }}/releases/download/v{{ prometheus_version }}/prometheus-{{ prometheus_version }}.{{ ansible_facts['system'] \| lower }}-{{ _prometheus_go_ansible_arch }}.tar.gz` | URL of the Prometheus `.tar.gz` release archive. Override for mirrors or air-gapped installs. Its file name is used to look up the SHA-256 in the checksums file, so it must appear in `prometheus_checksums_url`. The archive must contain `prometheus` and `promtool` at its top level directory. Downloaded to `prometheus_local_cache_path` on the target, or on the controller when `prometheus_download_local` is true. |
| `prometheus_checksums_url` | str | no | `https://github.com/{{ _prometheus_repo }}/releases/download/v{{ prometheus_version }}/sha256sums.txt` | URL of the `sha256sums` file used to verify the downloaded archive. Each line must be `<sha256>  <file name>`. Set to an empty string to skip checksum verification. A mismatch, or a missing entry for the archive file name, fails the play. |
| `prometheus_config_dir` | str | no | `/etc/prometheus` | Directory for the Prometheus configuration. Holds `prometheus.yml`, `web_config.yml`, `rules/`, `file_sd/`, `scrape_configs/` and, for versions below 3.0.0, `consoles/` and `console_libraries/`. Created with mode 0775 and owned by `prometheus_system_user`. Also set as that user's home directory. Changing it does not move existing files. |
| `prometheus_db_dir` | str | no | `/var/lib/prometheus` | Directory for the time series database, passed as `--storage.tsdb.path`, or `--storage.agent.path` in agent mode. It is the only writable path in the systemd unit. Created with mode 0755 and owned by `prometheus_system_user`. Changing it restarts the service and does not move existing data. |
| `prometheus_read_only_dirs` | list of str | no | `[]` | Additional paths Prometheus may read, added as `ReadOnlyPaths` to the systemd unit. Needed for TLS certificates or other files outside `prometheus_config_dir` and `prometheus_db_dir`, because the unit uses `ProtectSystem=strict` where supported. Changing it restarts the service. |
| `prometheus_binary_install_dir` | str | no | `/usr/local/bin` | Directory where `prometheus` and `promtool` are installed, owned by root with mode 0755. Used in `ExecStart` and by `promtool` to validate the configuration and rules before they are deployed. Changing it installs the binaries in the new location and restarts the service. Binaries in the old location are not removed. |
| `prometheus_web_listen_address` | str | no | `0.0.0.0:9090` | Address and port Prometheus listens on, as `host:port`, passed as `--web.listen-address`. Validated against `.+:\d+$`, otherwise the role fails. On hosts with SELinux enabled the port is added to `http_port_t`. Changing it restarts the service. Must not also be set in `prometheus_config_flags_extra`. |
| `prometheus_web_config` | dict | no | `{"basic_auth_users": {}, "http_server_config": {}, "tls_server_config": {}}` | Prometheus web configuration (TLS and basic auth) as a dict with all three keys `tls_server_config`, `http_server_config` and `basic_auth_users`; omitting one fails the play. `web_config.yml` is written to `prometheus_config_dir` and `--web.config.file` is added (Prometheus 2.24.0+) only when at least one key is non-empty. Changes restart the service. Replaces the whole default, so keep unused keys as `{}`. See the exporter-toolkit web configuration documentation for the content of each key. |
| `prometheus_web_external_url` | str | no | `""` | External URL under which Prometheus is reachable, passed as `--web.external-url`. Set it when running behind a reverse proxy or under a sub-path. Also used to derive the default `prometheus_metrics_path`. Changing it restarts the service. Must not also be set in `prometheus_config_flags_extra`. |
| `prometheus_metrics_path` | str | no | `/{{ (prometheus_web_external_url + '/metrics') \| regex_replace('^(.*://)?(.*?)/') }}` | Path of the metrics endpoint. Only used as `metrics_path` of the `prometheus` job in the default `prometheus_scrape_configs`; it has no effect if you override that variable without referencing it. The default is derived from `prometheus_web_external_url` by dropping the scheme and host and appending `/metrics`. |
| `prometheus_storage_retention` | str | no | `30d` | How long to keep samples, for example `30d` or `15d`, passed as `--storage.tsdb.retention.time` (`--storage.tsdb.retention` below Prometheus 2.7.0). Ignored in agent mode. Changing it restarts the service. Must not also be set in `prometheus_config_flags_extra`. |
| `prometheus_storage_retention_size` | str | no | `0` | Maximum size of stored blocks, as a number with a unit (B, KB, MB, GB, TB, PB), passed as `--storage.tsdb.retention.size`. `0` disables the size limit. Not applied below Prometheus 2.7.0 or in agent mode. Changing it restarts the service. |
| `prometheus_agent_mode` | bool | no | `false` | The Agent mode optimises Prometheus for the remote write use case. It disables querying, alerting, and local storage. |
| `prometheus_config_flags_extra` | dict | no | `{}` | Additional configuration flags passed to prometheus binary at startup. Keys are flag names without the leading dashes. A string value is rendered as `--flag=value`, a list as the flag repeated once per item, and an empty string or false as the bare flag. Other values (numbers, true) are dropped, so quote them. Flags the role manages (`config.file`, `web.listen-address`, `web.external-url`, `storage.tsdb.path`, `storage.tsdb.retention`, `storage.local.path`, `storage.local.retention`) are rejected. Changing it restarts the service. Example: prometheus_config_flags_extra: { alertmanager.timeout: 10s } |
| `prometheus_alertmanager_config` | list of dict | no | `[]` | Alertmanager configuration entries written to the `alerting.alertmanagers` section, for example `static_configs`. The section is omitted when the list is empty. |
| `prometheus_alert_relabel_configs` | list of dict | no | `[]` | Alert relabeling rules, as a list of Prometheus `alert_relabel_configs` entries, applied before alerts are sent to Alertmanager. Rendered under `alerting` only when `prometheus_alertmanager_config` is not empty; otherwise ignored. Changes reload the service. |
| `prometheus_global` | dict | no | `{"evaluation_interval": "15s", "scrape_interval": "15s", "scrape_timeout": "10s"}` | Content of the Prometheus `global` section, for example `scrape_interval`, `scrape_timeout` and `evaluation_interval` (durations such as `15s`). Replaces the whole default dict, so set every key you need. `external_labels` is rejected here; use `prometheus_external_labels`. Changes reload the service. |
| `prometheus_remote_write` | list of dict | no | `[]` | Remote write endpoints. Each item needs `url`; see the Prometheus `remote_write` configuration for the other keys. |
| `prometheus_remote_read` | list of dict | no | `[]` | Remote read endpoints. Each item needs `url`; see the Prometheus `remote_read` configuration for the other keys. |
| `prometheus_external_labels` | dict | no | `{"environment": "{{ ansible_fqdn \| default(ansible_host) \| default(inventory_hostname) }}"}` | Additional labels added to all time series and alerts when communicating with external systems |
| `prometheus_targets` | dict | no | `{}` | Targets for file-based service discovery. Each key becomes `<prometheus_config_dir>/file_sd/<key>.yml` with the value rendered as YAML, usually a list of `targets` and `labels` entries. Every key must be referenced in `prometheus_scrape_configs` as a `file_sd_configs` file with that exact path, otherwise the role fails. Files for keys you remove are not deleted. Changes reload the service. |
| `prometheus_scrape_configs` | list of dict | no | `[{"job_name": "prometheus", "metrics_path": "{{ prometheus_metrics_path }}", "static_configs": [{"targets": ["{{ ansible_fqdn \| default(ansible_host) \| default('localhost') }}:9090"]}]}, {"file_sd_configs": [{"files": ["{{ prometheus_config_dir }}/file_sd/node.yml"]}], "job_name": "node"}]` | Prometheus scrape job configurations. Defaults to a `prometheus` job scraping the local server and a `node` job reading targets from `file_sd/node.yml`. |
| `prometheus_config_file` | str | no | `prometheus.yml.j2` | Name of the template used to render `prometheus.yml`, looked up in the Ansible template search path. Set it to use your own template instead of the one shipped with the role. The result is validated with `promtool check config` before it replaces the file. A custom template must render every section it needs, because the other `prometheus_*` variables only take effect through the template. Changes reload the service. |
| `prometheus_alert_rules` | list of dict | no | `[]` | Alerting rules, as a list of Prometheus rule dicts (for example `alert`, `expr`, `for`, `labels`, `annotations`), written to one group in `rules/ansible_managed.yml` and validated with `promtool check rules`. Not deployed in agent mode. Needs `prometheus_alert_rules_files` to be non-empty so that `prometheus.yml` loads the `rules/` directory. Changes reload the service. A warning is shown when rules are set without `prometheus_alertmanager_config`. |
| `prometheus_alert_rules_files` | list of str | no | `["prometheus/rules/*.yml", "prometheus/rules/*.yaml"]` | Glob patterns, resolved on the Ansible controller, of rule files to copy to `rules/` after validation with `promtool check rules`. Skipped in agent mode. `prometheus.yml` loads `rules/*.yml` and `rules/*.yaml` only when this list is not empty, which also applies to `prometheus_alert_rules`. Copied files are not removed when they disappear from the list. Changes reload the service. |
| `prometheus_static_targets_files` | list of str | no | `["prometheus/targets/*.yml", "prometheus/targets/*.json"]` | Glob patterns, resolved on the Ansible controller, of file-based service discovery files to copy to `file_sd/`. Reference them from `prometheus_scrape_configs`. Copied files are not removed when they disappear from the list. Changes reload the service. |
| `prometheus_scrape_config_files` | list of str | no | `["prometheus/scrape_configs/*.yml", "prometheus/scrape_configs/*.json"]` | Glob patterns, resolved on the Ansible controller, of scrape config files to copy to `scrape_configs/`. `prometheus.yml` includes `scrape_configs/*` only when this list is not empty and Prometheus is 2.43.0 or later. Copied files are not removed when they disappear from the list. Changes reload the service. |
| `prometheus_system_group` | str | no | `prometheus` | System group that owns the configuration and data directories and runs the service. Created if missing. Changing it creates the new group and restarts the service. The old group is not removed. |
| `prometheus_system_user` | str | no | `prometheus` | System user that owns the configuration and data directories and runs the service. Created without a login shell and with `prometheus_config_dir` as home. Changing it creates the new user and restarts the service. The old user is not removed. |
| `prometheus_stop_timeout` | str | no | `600s` | Time systemd waits for Prometheus to stop before killing it, set as `TimeoutStopSec`. Accepts systemd time spans such as `600s` or `10min`. Changing it restarts the service. |
| `prometheus_enable_service` | bool | no | `true` | Whether to start and enable the Prometheus service. Set to false for image builds. |
| `prometheus_download_local` | bool | no | `false` | Download and verify the archive on the Ansible controller and copy it to the target (`true`, for targets without internet access), or download it on the target (`false`) |
| `prometheus_local_cache_path` | str | no | `/tmp/prometheus-{{ ansible_facts['system'] \| lower }}-{{ _prometheus_go_ansible_arch }}/{{ prometheus_version }}` | Directory where the archive is downloaded and unpacked, and from which binaries (and console files below Prometheus 3.0.0) are copied. Created on the host that downloads: the controller when `prometheus_download_local` is true, the target otherwise. The default includes the version, so each version gets its own directory and an existing download is reused. Old directories are not cleaned up. |
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
