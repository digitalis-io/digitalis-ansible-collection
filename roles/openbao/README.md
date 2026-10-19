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

Generated from `meta/argument_specs.yml`; run `scripts/generate-docs.sh` to refresh.

<!-- BEGIN_ANSIBLE_DOCS -->

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `openbao_version` | str | no | `2.7.1` | Package version to install, for example `2.7.1`. |
| `openbao_manage_repository` | bool | no | `true` | Configure the pkgs.openbao.org repository. Disable when an internal mirror is already configured. |
| `openbao_gpg_key_url` | str | no | `https://openbao.org/assets/openbao-gpg-pub-20240618.asc` | URL of the package signing key. |
| `openbao_validate_certs` | bool | no | `true` | Validate TLS certificates when downloading the signing key. |
| `openbao_apt_repository_uri` | str | no | `https://pkgs.openbao.org/deb` | APT repository URI. |
| `openbao_apt_repository_suite` | str | no | `stable` | APT repository suite. |
| `openbao_apt_repository_components` | str | no | `main` | APT repository components. |
| `openbao_yum_repository_baseurl` | str | no | `https://pkgs.openbao.org/rpm/$basearch` | YUM/DNF repository base URL. |
| `openbao_service_manage` | bool | no | `false` | Manage the `openbao` server service using the two options below. |
| `openbao_service_enabled` | bool | no | `true` | Enable the `openbao` server service at boot. |
| `openbao_service_state` | str | no | `started` | State of the `openbao` server service. One of `started`, `stopped`, `restarted`. |
| `openbao_config_manage` | bool | no | `false` | Render `/etc/openbao/openbao.hcl` from the options below. When false the packaged configuration is left untouched. The rendered file is checked with `bao operator validate-config` before it replaces the current one. |
| `openbao_ui` | bool | no | `true` | Enable the web UI. |
| `openbao_api_addr` | str | no | `""` | Address advertised to clients. Omitted when empty. |
| `openbao_cluster_addr` | str | no | `""` | Address advertised to other cluster members. Omitted when empty. Required by raft storage. |
| `openbao_storage_type` | str | no | `pebbledb` | Storage backend type. |
| `openbao_storage_config` | dict | no | `{"path": "/opt/openbao/data"}` | Options for the storage block. |
| `openbao_listeners` | list of dict | no | `[{'type': 'tcp', 'address': '0.0.0.0:8200', 'tls_cert_file': '/opt/openbao/tls/tls.crt', 'tls_key_file': '/opt/openbao/tls/tls.key'}]` | Listener blocks. `type` is `tcp` (default) or `unix` and `address` is required. Every other key is written as a listener option; nested mappings become nested blocks. |
| `openbao_telemetry` | dict | no | `{}` | Options for the telemetry block. Omitted when empty. |
| `openbao_plugins` | list of dict | no | `[]` | Declarative plugins. Each item needs `type` (`secret`, `auth` or `database`), `name`, `version` and exactly one of `image` or `command`. `image` must be pinned by digest or paired with `sha256sum`. Optional keys are `sha256sum`, `binary_name`, `args` and `env`. Requires `openbao_config_manage`. |
| `openbao_plugin_directory` | str | no | `/opt/openbao/plugins` | Plugin directory, created for the `openbao` user when `openbao_plugins` is not empty. |
| `openbao_plugin_auto_download` | bool | no | `true` | Download OCI plugins at startup and on reload. |
| `openbao_plugin_auto_register` | bool | no | `true` | Register declared plugins in the catalog at startup and on reload. |
| `openbao_plugin_download_behavior` | str | no | `fail` | Whether a failed plugin download stops the server from starting. One of `fail`, `warn`. |
| `openbao_extra_config` | str | no | `""` | Raw HCL appended to the server configuration. |
| `openbao_init` | bool | no | `false` | Initialise the cluster with `bao operator init` on the first host of the play when it is not initialised yet. Requires `openbao_service_manage` and a started service. The unseal keys and root token are written to `openbao_init_output_file`. |
| `openbao_init_secret_shares` | int | no | `5` | Number of unseal key shares to generate. |
| `openbao_init_secret_threshold` | int | no | `3` | Number of key shares needed to unseal. Must not exceed `openbao_init_secret_shares`. |
| `openbao_init_output_file` | str | no | `/root/openbao-init.json` | File on the initialised host that receives the init output, readable by root only. |
| `openbao_init_address` | str | no | `https://127.0.0.1:8200` | Server address used by the init commands. |
| `openbao_init_skip_verify` | bool | no | `true` | Skip TLS verification for the init commands, needed by the packaged self-signed certificate. |
<!-- END_ANSIBLE_DOCS -->

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

With `openbao_init: true` the role runs `bao operator init` once, on the first
host of the play, when the cluster is not initialised yet; later runs change
nothing. It needs `openbao_service_manage` with a started service. The unseal
keys and root token are written to `openbao_init_output_file` on that host
(`root` only, mode `0600`) and are not logged. Copy them to a secrets manager
and delete the file. Nodes stay sealed unless auto-unseal is configured, so
unseal them separately. Set `openbao_init_address` to `http://...` when the
listener has `tls_disable`.

```yaml
- role: digitalis.digitalis.openbao
  vars:
    openbao_service_manage: true
    openbao_init: true
```

See also the complete playbook in [examples/openbao-agent-secret](../../examples/openbao-agent-secret/playbook.yml).

## Supported platforms

Red Hat Enterprise Linux 9 and 10 (and rebuilds), Debian 12 and 13, Ubuntu 22.04 and 24.04.

## Testing

```bash
MOLECULE_DISTRO=rockylinux9 molecule test
MOLECULE_DISTRO=rockylinux9 molecule test -s invalid-version
MOLECULE_DISTRO=rockylinux9 molecule test -s config
MOLECULE_DISTRO=rockylinux9 molecule test -s init
MOLECULE_DISTRO=rockylinux9 molecule test -s invalid-config
```

## License

Apache License 2.0. Derived from
[ansible-role-openbao](https://github.com/robertdebock/ansible-role-openbao) by
Robert de Bock; see [NOTICE](NOTICE).

---

Maintained by [Digitalis.io](https://digitalis.io). Support at [digitalis.io/contact](https://digitalis.io/contact).
