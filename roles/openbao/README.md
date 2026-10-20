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
| `openbao_version` | str | no | `2.7.1` | Package version to install, for example `2.7.1`. It is appended to the package name (`openbao=VERSION` on APT, `openbao-VERSION` on DNF/YUM) and must exist in the configured repository. Must look like a package version (`MAJOR.MINOR.PATCH` with an optional suffix); the role fails before changing the host otherwise. The role does not restart the service after a package change. |
| `openbao_manage_repository` | bool | no | `true` | Configure the pkgs.openbao.org repository and its signing key before installing the package. Disable when an internal mirror is already configured. When false, `openbao_gpg_key_url`, `openbao_validate_certs`, the `openbao_apt_repository_*` options and `openbao_yum_repository_baseurl` are not used. |
| `openbao_gpg_key_url` | str | no | `https://openbao.org/assets/openbao-gpg-pub-20240618.asc` | URL of the package signing key. On Debian and Ubuntu it is downloaded to `/etc/apt/keyrings/openbao.asc` and referenced by the APT source; on Red Hat it is imported into the RPM keyring and set as `gpgkey` of the repository. Used only when `openbao_manage_repository` is true. |
| `openbao_validate_certs` | bool | no | `true` | Validate the TLS certificate of the server hosting the signing key when downloading it from `openbao_gpg_key_url`. Disable only for a mirror with a private certificate. Does not affect package downloads. Used only when `openbao_manage_repository` is true. |
| `openbao_apt_repository_uri` | str | no | `https://pkgs.openbao.org/deb` | Base URI of the APT repository, written as `URIs` in `/etc/apt/sources.list.d/openbao.sources`. Debian and Ubuntu only. Used only when `openbao_manage_repository` is true. A change refreshes the APT cache. |
| `openbao_apt_repository_suite` | str | no | `stable` | APT suite, written as `Suites` in `/etc/apt/sources.list.d/openbao.sources`. Debian and Ubuntu only. Used only when `openbao_manage_repository` is true. A change refreshes the APT cache. |
| `openbao_apt_repository_components` | str | no | `main` | APT components, written as `Components` in `/etc/apt/sources.list.d/openbao.sources`; separate several with spaces. Debian and Ubuntu only. Used only when `openbao_manage_repository` is true. A change refreshes the APT cache. |
| `openbao_yum_repository_baseurl` | str | no | `https://pkgs.openbao.org/rpm/$basearch` | Base URL of the `openbao` YUM/DNF repository, with package signature checking enabled. Red Hat family only. `$basearch` is expanded by the package manager. Used only when `openbao_manage_repository` is true. |
| `openbao_service_manage` | bool | no | `false` | Manage the `openbao` systemd unit using `openbao_service_enabled` and `openbao_service_state`. When false the role only installs the package and leaves the unit as the package created it (disabled and stopped on a fresh install). Required by `openbao_init`. Also a precondition for the restart that follows a configuration change (see `openbao_config_manage`). |
| `openbao_service_enabled` | bool | no | `true` | Whether the `openbao` unit starts at boot. Used only when `openbao_service_manage` is true. |
| `openbao_service_state` | str | no | `started` | State the `openbao` unit is set to on every run. `restarted` restarts the service on each run, so the task always reports a change and the server is briefly unavailable. Used only when `openbao_service_manage` is true. The restart after a configuration change only happens with `started`; `openbao_init` accepts `started` and `restarted`. One of `started`, `stopped`, `restarted`. |
| `openbao_config_manage` | bool | no | `false` | Render `/etc/openbao/openbao.hcl` from the server options below (UI, addresses, storage, listeners, telemetry, plugins and extra configuration). When false the packaged configuration is left untouched and those options are ignored. The rendered file is checked with `bao operator validate-config` before it replaces the current one; a file that fails validation is not installed. A change to the file restarts the service at the end of the play, only when `openbao_service_manage` is true, `openbao_service_state` is `started` and the service was already running when the role started. |
| `openbao_ui` | bool | no | `true` | Enable the web UI. Written as `ui` in the rendered configuration. Used only when `openbao_config_manage` is true. A change restarts the service (see `openbao_config_manage`). |
| `openbao_api_addr` | str | no | `""` | Address clients should use to reach this node, for example `https://openbao1.example.com:8200`. Written as `api_addr`; the line is omitted when empty. Used only when `openbao_config_manage` is true. Must be a string. |
| `openbao_cluster_addr` | str | no | `""` | Address other cluster members should use to reach this node, for example `https://openbao1.example.com:8201`. Written as `cluster_addr`; the line is omitted when empty. Required by raft storage; the role does not check this. Used only when `openbao_config_manage` is true. Must be a string. |
| `openbao_storage_type` | str | no | `pebbledb` | Storage backend, used as the label of the `storage` block, for example `pebbledb` or `raft`. Any non-empty string is accepted; OpenBao decides whether the backend exists when the rendered file is validated. Used only when `openbao_config_manage` is true. Changing it on a host with data does not migrate that data. |
| `openbao_storage_config` | dict | no | `{"path": "/opt/openbao/data"}` | Options of the `storage` block. Each key becomes `key = value` with the value written as JSON; a nested mapping becomes a nested block and a list of mappings becomes repeated blocks. Used only when `openbao_config_manage` is true. Must be a mapping. |
| `openbao_listeners` | list of dict | no | `[{"address": "0.0.0.0:8200", "tls_cert_file": "/opt/openbao/tls/tls.crt", "tls_key_file": "/opt/openbao/tls/tls.key", "type": "tcp"}]` | Listener blocks, each rendered as `listener "TYPE" { ... }`. `type` is `tcp` (default) or `unix` and a non-empty string `address` is required; the list must not be empty. Every other key is written as `key = value` with the value written as JSON; nested mappings become nested blocks. Used only when `openbao_config_manage` is true. Replacing the list replaces the packaged listener, including its TLS settings. |
| `openbao_telemetry` | dict | no | `{}` | Options of the `telemetry` block, for example `{prometheus_retention_time: 24h, disable_hostname: true}`. Rendered like `openbao_storage_config`; the block is omitted when empty. Used only when `openbao_config_manage` is true. Must be a mapping. |
| `openbao_plugins` | list of dict | no | `[]` | Declarative plugins written as `plugin` blocks. Each item needs `type` (`secret`, `auth` or `database`), `name`, `version` and exactly one of `image` (OCI image reference) or `command` (binary already present in `openbao_plugin_directory`). `image` must be pinned by digest (`@sha256:...`) or paired with `sha256sum`, which must be 64 lowercase hex characters. Optional keys are `sha256sum`, `binary_name`, `args` (list) and `env` (list of `KEY=value`); any other key is rejected, as is a repeated `type` and `name` pair. Requires `openbao_config_manage`. When not empty, the plugin directory is created and the plugin server options are rendered. |
| `openbao_plugin_directory` | str | no | `/opt/openbao/plugins` | Absolute path of the plugin directory, written as `plugin_directory`. It is created owned by `openbao` with mode `0750`. Used, and checked to be absolute, only when `openbao_plugins` is not empty. Requires `openbao_config_manage` to be created and rendered. |
| `openbao_plugin_auto_download` | bool | no | `true` | Written as `plugin_auto_download`: whether OpenBao downloads declared OCI plugin images itself at startup and on reload. Rendered, and checked to be a boolean, only when `openbao_plugins` is not empty. Requires `openbao_config_manage`. |
| `openbao_plugin_auto_register` | bool | no | `true` | Written as `plugin_auto_register`: whether OpenBao registers declared plugins in its catalog at startup and on reload. Rendered, and checked to be a boolean, only when `openbao_plugins` is not empty. Requires `openbao_config_manage`. |
| `openbao_plugin_download_behavior` | str | no | `fail` | Written as `plugin_download_behavior`: whether a failed plugin download stops the server from starting (`fail`) or is only logged as a warning (`warn`). Rendered only when `openbao_plugins` is not empty. Requires `openbao_config_manage`. One of `fail`, `warn`. |
| `openbao_extra_config` | str | no | `""` | Raw HCL appended unchanged to the end of the rendered configuration, for example a `seal` stanza. Nothing is added when empty. Used only when `openbao_config_manage` is true. The whole file is checked with `bao operator validate-config` first, so invalid HCL or an unknown option fails the task and leaves the current file in place. |
| `openbao_init` | bool | no | `false` | Initialise the cluster with `bao operator init` on the first host of the play when it reports not initialised; the role waits up to about a minute for the server to answer first. A cluster that is already initialised is left alone. Requires `openbao_service_manage` with `openbao_service_state` `started` or `restarted`. The unseal keys and root token are written to `openbao_init_output_file` on that host. The cluster is left sealed unless auto-unseal is configured, and other nodes must be unsealed separately. |
| `openbao_init_secret_shares` | int | no | `5` | Number of unseal key shares, passed as `-key-shares` to `bao operator init`. Must be at least 1. Validated on every run, but only used when `openbao_init` is true. Cannot be changed afterwards: the cluster is initialised only once. |
| `openbao_init_secret_threshold` | int | no | `3` | Number of shares required to unseal, passed as `-key-threshold`. Must be at least 1 and not exceed `openbao_init_secret_shares`. Validated on every run, but only used when `openbao_init` is true. |
| `openbao_init_output_file` | str | no | `/root/openbao-init.json` | Absolute path on the initialised host that receives the `bao operator init` JSON output (unseal keys and root token), owned by root with mode `0600`. Validated on every run, but only written by the run that initialises the cluster. Move its content to a secrets manager and remove the file. |
| `openbao_init_address` | str | no | `https://127.0.0.1:8200` | Address of the server, exported as `BAO_ADDR` to the `bao operator init` commands run on the host. Must start with `http://` or `https://`. Validated on every run, but only used when `openbao_init` is true. |
| `openbao_init_skip_verify` | bool | no | `true` | Exported as `BAO_SKIP_VERIFY` to the init commands, which skips TLS verification. Needed by the packaged self-signed certificate; set to false when `openbao_init_address` serves a trusted certificate. Only used when `openbao_init` is true. |
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
