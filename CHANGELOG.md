# Changelog

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
