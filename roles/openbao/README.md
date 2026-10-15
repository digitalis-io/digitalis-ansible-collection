<p align="center">
  <a href="https://digitalis.io">
    <img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/DigitalisDigital_DigitalisFullLogoGradient+-+medium.png" alt="Digitalis.io" width="300">
  </a>
</p>

<p align="center">
  <em>Built and maintained by <a href="https://digitalis.io">Digitalis.io</a></em>
</p>

# openbao

Install the OpenBao server package from the upstream repository on Red Hat Enterprise Linux, Debian and Ubuntu, and optionally manage its configuration and OCI plugins.

## Quick start

```yaml
- name: Install OpenBao
  hosts: openbao
  become: true
  roles:
    - role: digitalis.digitalis.openbao
```

The package creates the `openbao` user, `/etc/openbao/openbao.hcl` and the
`openbao` systemd unit. The service is left as the package created it unless
`openbao_service_manage` is true, and the configuration is left as the package
shipped it unless `openbao_config_manage` is true.

## Examples

Pin a version and start the server with the packaged configuration:

```yaml
- role: digitalis.digitalis.openbao
  vars:
    openbao_version: "2.7.1"
    openbao_service_manage: true
```

Install from an internal mirror that is already configured on the host:

```yaml
- role: digitalis.digitalis.openbao
  vars:
    openbao_manage_repository: false
```

Manage the configuration with raft storage, TLS from your own certificates and
Prometheus telemetry:

```yaml
- role: digitalis.digitalis.openbao
  vars:
    openbao_service_manage: true
    openbao_config_manage: true
    openbao_api_addr: "https://{{ ansible_facts['fqdn'] }}:8200"
    openbao_cluster_addr: "https://{{ ansible_facts['fqdn'] }}:8201"
    openbao_storage_type: raft
    openbao_storage_config:
      path: /opt/openbao/data
      node_id: "{{ inventory_hostname }}"
    openbao_listeners:
      - address: "0.0.0.0:8200"
        tls_cert_file: /etc/ssl/openbao/tls.crt
        tls_key_file: /etc/ssl/openbao/tls.key
    openbao_telemetry:
      prometheus_retention_time: 24h
      disable_hostname: true
```

Install a secrets plugin from an OCI registry. The server downloads it into
`openbao_plugin_directory` at startup and registers it in the catalog once
unsealed:

```yaml
- role: digitalis.digitalis.openbao
  vars:
    openbao_service_manage: true
    openbao_config_manage: true
    openbao_plugins:
      - type: secret
        name: aws
        image: ghcr.io/openbao/openbao-plugin-secrets-aws:v0.1.0@sha256:ffff79125690e9a1f4cfd3e6d851657386a97c2e96e8d66a82adddb53e0b7359
        version: v0.1.0
```

## Variables

| Variable | Type | Default | Example |
|----------|------|---------|---------|
| `openbao_version` | str | `2.7.1` | `2.6.4` |
| `openbao_manage_repository` | bool | `true` | `false` |
| `openbao_gpg_key_url` | str | `https://openbao.org/assets/openbao-gpg-pub-20240618.asc` | mirror URL |
| `openbao_validate_certs` | bool | `true` | `false` |
| `openbao_apt_repository_uri` | str | `https://pkgs.openbao.org/deb` | mirror URL |
| `openbao_apt_repository_suite` | str | `stable` | `stable` |
| `openbao_apt_repository_components` | str | `main` | `main` |
| `openbao_yum_repository_baseurl` | str | `https://pkgs.openbao.org/rpm/$basearch` | mirror URL |
| `openbao_service_manage` | bool | `false` | `true` |
| `openbao_service_enabled` | bool | `true` | `false` |
| `openbao_service_state` | str | `started` | `stopped` |
| `openbao_config_manage` | bool | `false` | `true` |
| `openbao_ui` | bool | `true` | `false` |
| `openbao_api_addr` | str | `""` | `https://openbao1.example.com:8200` |
| `openbao_cluster_addr` | str | `""` | `https://openbao1.example.com:8201` |
| `openbao_storage_type` | str | `pebbledb` | `raft` |
| `openbao_storage_config` | dict | `{path: /opt/openbao/data}` | `{path: /opt/openbao/data, node_id: node1}` |
| `openbao_listeners` | list | TLS listener on `0.0.0.0:8200` with the packaged certificate | `[{address: "127.0.0.1:8200", tls_disable: true}]` |
| `openbao_telemetry` | dict | `{}` | `{prometheus_retention_time: 24h}` |
| `openbao_plugins` | list | `[]` | see the example above |
| `openbao_plugin_directory` | str | `/opt/openbao/plugins` | `/opt/openbao/oci-plugins` |
| `openbao_plugin_auto_download` | bool | `true` | `false` |
| `openbao_plugin_auto_register` | bool | `true` | `false` |
| `openbao_plugin_download_behavior` | str | `fail` | `warn` |
| `openbao_extra_config` | str | `""` | `seal "transit" { ... }` |

`openbao_version` must be a full package version such as `2.7.1`; anything
else fails before the host is changed.

The configuration defaults match the storage, listener and UI settings of the
packaged file. Each `openbao_listeners` item needs an `address`; `type`
defaults to `tcp` and every other key is written as a listener option. In
listener, storage and telemetry options a nested mapping becomes a nested
block and a list of mappings becomes one block per item, so raft
`retry_join` is written as a list. Use `openbao_extra_config` for anything without a variable, such as
`seal` stanzas. The rendered file is owned by `root:openbao` with mode `0640`
and is checked with `bao operator validate-config` before it replaces the
current one, so a typo or unknown option fails the run and leaves the old file
in place. A change restarts the server when `openbao_service_manage` is true,
`openbao_service_state` is `started` and the server was already running.
Restarting seals the node unless auto-unseal is configured, so apply the role
to a cluster with `serial: 1` and unseal each node before moving on.

Each `openbao_plugins` item needs `type` (`secret`, `auth` or `database`),
`name`, `version` and exactly one of `image` (an OCI reference) or `command`
(a binary already in `openbao_plugin_directory`). OpenBao refuses an image that
is neither pinned by digest nor paired with `sha256sum`, so the role checks
this up front. Optional keys are `sha256sum`, `binary_name`, `args` and `env`.
Plugins require `openbao_config_manage`; the plugin options and directory are
only written when at least one plugin is declared. The parent of
`openbao_plugin_directory` must already exist.

## Supported platforms

Red Hat Enterprise Linux 9 and 10 (and rebuilds), Debian 12 and 13, Ubuntu 22.04 and 24.04.

## Testing

```bash
MOLECULE_DISTRO=rockylinux9 molecule test
MOLECULE_DISTRO=rockylinux9 molecule test -s invalid-version
MOLECULE_DISTRO=rockylinux9 molecule test -s config
MOLECULE_DISTRO=rockylinux9 molecule test -s invalid-config
```

## License

Apache License 2.0. Derived from
[ansible-role-openbao](https://github.com/robertdebock/ansible-role-openbao) by
Robert de Bock; see [NOTICE](NOTICE).

---

Maintained by [Digitalis.io](https://digitalis.io). Support at [digitalis.io/contact](https://digitalis.io/contact).
