# Changelog

## Unreleased

- `rabbitmq`: role moved in from ansible-role-rabbitmq. The collection now
  depends on `community.rabbitmq` and `ansible.posix`.
- `prometheus`: role moved in from ansible-role-prometheus.
- `openbao_agent`: complete the argument specs, add spec defaults for
  `openbao_agent_auth_mount_path` and `openbao_agent_token_sink_path`, and
  rewrite the variable descriptions.
- `openbao_agent`: rename the internal variables `openbao_agent_auth_methods`,
  `openbao_agent_forbidden_dest_dirs`, `openbao_agent_template_dest_dirs` and
  `openbao_agent_template_keys` to `_openbao_agent_auth_methods`,
  `_openbao_agent_forbidden_dest_dirs`, `_openbao_agent_template_dest_dirs` and
  `_openbao_agent_template_keys`. They are not part of the role interface;
  playbooks that overrode them must stop doing so.

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
