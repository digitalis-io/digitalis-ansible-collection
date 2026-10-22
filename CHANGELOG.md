# Changelog

## Unreleased

- `postgres_cluster`: new role, moved in from ar-postgres-cluster. It deploys a
  PostgreSQL cluster under Patroni with ZooKeeper, pgBackRest, HAProxy, pgAudit
  and pgAgent on Red Hat, Debian and Ubuntu. All variables are renamed with the
  `postgres_cluster_` prefix and documented in `meta/argument_specs.yml`; the
  role README has a migration table. Notable changes from the old role: Patroni
  runs from a virtual environment, passwords have no default, the pgBackRest
  repository type is explicit, and configuration changes reload Patroni instead
  of restarting it. The collection now depends on `community.postgresql`,
  `community.crypto` and `community.general`.
- `rabbitmq`: role moved in from ansible-role-rabbitmq. The collection now
  depends on `community.rabbitmq` and `ansible.posix`.
- `prometheus`: role moved in from ansible-role-prometheus.
- Role READMEs list variables generated from `meta/argument_specs.yml` with
  `aar-doc`; run `scripts/generate-docs.sh` to refresh them. The `examples/`
  directory holds complete playbooks.
- Internal constants in `vars/` now have a `_` prefix and are private. An
  override of an old name is ignored without an error: `openbao_apt_keyring`,
  `openbao_package_name` (now `_openbao_package`), `openbao_supported_os_families`,
  `openbao_config_file`, `openbao_plugin_types`, `openbao_plugin_keys`,
  `openbao_init_environment`, `openbao_agent_auth_methods`,
  `openbao_agent_template_keys`, `openbao_agent_forbidden_dest_dirs`,
  `openbao_agent_template_dest_dirs` and `prometheus_github_api_headers`.
- `openbao_agent`: `openbao_agent_templates` items are validated on entry; a
  missing `destination` or an unknown key now fails with an argument spec error.
- CI checks that every role variable is documented in its spec and that the
  generated READMEs are current.

## 0.1.0

- `openbao`: role imported from ansible-role-openbao by Robert de Bock and
  rebranded under Digitalis.io.
- `openbao`: support Red Hat Enterprise Linux 9 and 10, Debian 12 and 13, and
  Ubuntu 22.04 and 24.04 using a deb822 APT source on every Debian family
  release.
- `openbao`: default to OpenBao 2.7.1, validate TLS when fetching the signing
  key, validate `openbao_version`, and add optional server service management.
- `openbao`: optionally render `/etc/openbao/openbao.hcl` from role variables
  (listeners, storage, advertised addresses, UI, telemetry and raw HCL),
  validated with `bao operator validate-config` and applied with a restart.
- `openbao`: declare plugins in the server configuration, including plugins
  downloaded from OCI registries, with a managed plugin directory.
- `openbao_agent`: new role that installs OpenBao Agent with AppRole or token
  auto-auth, a token sink, an optional local API proxy and file templates.
