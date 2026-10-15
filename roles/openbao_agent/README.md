<p align="center">
  <a href="https://digitalis.io">
    <img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/DigitalisDigital_DigitalisFullLogoGradient+-+medium.png" alt="Digitalis.io" width="300">
  </a>
</p>

<p align="center">
  <em>Built and maintained by <a href="https://digitalis.io">Digitalis.io</a></em>
</p>

# openbao_agent

Install [OpenBao Agent](https://openbao.org/docs/agent-and-proxy/agent/) as a
systemd service that authenticates to an OpenBao server and renders secrets to
files using [templates](https://openbao.org/docs/agent-and-proxy/agent/template/).

## Quick start

```yaml
- name: Render application secrets
  hosts: app_servers
  become: true
  roles:
    - role: digitalis.digitalis.openbao_agent
      vars:
        openbao_agent_address: https://openbao.example.com:8200
        openbao_agent_approle_role_id: "{{ vault_openbao_role_id }}"
        openbao_agent_approle_secret_id: "{{ vault_openbao_secret_id }}"
        openbao_agent_templates:
          - destination: /etc/myapp/db.env
            perms: "0640"
            contents: !unsafe |
              {{ with secret "secret/data/myapp" }}DB_PASSWORD={{ .Data.data.password }}{{ end }}
```

Keep the AppRole credentials or token in ansible-vault or a secrets manager.
They are written to `/etc/openbao-agent` with mode `0600`, owned by the agent
user.

The agent runs as a dedicated `openbao-agent` user, separate from the
`openbao` server user.

Inline `contents` must be tagged `!unsafe` so Ansible leaves the `{{ }}`
markers for the agent. Files given with `src` are copied verbatim and need no
tagging.

## Examples

Template file from the controller, reloading the service that consumes it:

```yaml
openbao_agent_templates:
  - destination: /etc/nginx/tls/server.pem
    src: files/server.pem.ctmpl
    perms: "0640"
    exec_command: ["systemctl", "reload", "nginx"]
    exec_timeout: 30s
```

The agent runs as `openbao_agent_user` with `NoNewPrivileges` and no
capabilities, so a command such as `systemctl reload` needs a polkit rule that
allows that user to reload the unit.

Token auth with a local API proxy that injects the agent token:

```yaml
openbao_agent_auth_method: token_file
openbao_agent_token: "{{ vault_openbao_token }}"
openbao_agent_listener_address: 127.0.0.1:8100
```

## Variables

| Variable | Type | Default | Example |
|----------|------|---------|---------|
| `openbao_agent_address` | str | `""` (required) | `https://openbao.example.com:8200` |
| `openbao_agent_auth_method` | str | `approle` | `token_file` |
| `openbao_agent_auth_mount_path` | str | `auth/approle` | `auth/approle-apps` (approle only) |
| `openbao_agent_approle_role_id` | str | `""` | vaulted value |
| `openbao_agent_approle_secret_id` | str | `""` | vaulted value |
| `openbao_agent_token` | str | `""` | vaulted value |
| `openbao_agent_templates` | list | `[]` | see below |
| `openbao_agent_template_exit_on_retry_failure` | bool | `true` | `false` |
| `openbao_agent_template_static_secret_render_interval` | str | `5m` | `1h` |
| `openbao_agent_ca_cert` | str | `""` | `/etc/pki/tls/certs/openbao-ca.pem` |
| `openbao_agent_tls_server_name` | str | `""` | `openbao.example.com` |
| `openbao_agent_tls_skip_verify` | bool | `false` | `true` |
| `openbao_agent_retry_num_retries` | int | `12` | `5` |
| `openbao_agent_log_level` | str | `info` | `debug` |
| `openbao_agent_token_sink_enabled` | bool | `true` | `false` |
| `openbao_agent_token_sink_path` | path | `<data_dir>/agent-token` | `/var/lib/myapp/token` |
| `openbao_agent_token_sink_mode` | str | `0640` | `0600` |
| `openbao_agent_listener_address` | str | `""` | `127.0.0.1:8100` |
| `openbao_agent_listener_allow_nonlocal` | bool | `false` | `true` |
| `openbao_agent_template_default_perms` | str | `0600` | `0640` |
| `openbao_agent_extra_config` | str | `""` | raw HCL |
| `openbao_agent_install` | bool | `true` | `false` |
| `openbao_agent_user` | str | `openbao-agent` | `myapp` |
| `openbao_agent_group` | str | `openbao-agent` | `myapp` |
| `openbao_agent_config_dir` | path | `/etc/openbao-agent` | `/etc/bao-agent` |
| `openbao_agent_data_dir` | path | `/var/lib/openbao-agent` | `/srv/bao-agent` |
| `openbao_agent_service_name` | str | `openbao-agent` | `bao-agent` |
| `openbao_agent_service_enabled` | bool | `true` | `false` |
| `openbao_agent_service_state` | str | `started` | `stopped` |

With `openbao_agent_install: true` the [openbao](../openbao/README.md) role
installs the package, so `openbao_version` and its repository variables apply.
That role never touches the `openbao` server service when called from here.

### Template items

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `destination` | str | yes | Absolute path of the rendered file |
| `contents` | str | one of | Inline template, tagged `!unsafe` |
| `src` | str | one of | Controller file copied to `<config_dir>/templates/` |
| `source` | str | one of | Template file already on the host |
| `perms` | str | no | File mode, default `openbao_agent_template_default_perms` (`0600`) |
| `error_on_missing_key` | bool | no | Fail rendering on missing keys |
| `backup` | bool | no | Keep the previous render |
| `create_dest_dirs` | bool | no | Let the agent create parent directories |
| `left_delimiter`, `right_delimiter` | str | no | Template delimiters |
| `wait_min`, `wait_max` | str | no | Render quiescence timers |
| `exec_command` | list | no | Command run after a changed render |
| `exec_timeout` | str | no | Command timeout, default `30s`; requires `exec_command` |

Missing destination directories are created for the agent user. Existing
directories are not changed, so the agent user must be able to write to them.
Destinations directly in `/`, `/etc`, `/usr`, `/var` or `/boot` are refused;
use a subdirectory. Set `openbao_agent_group` to the group of the consuming
service so it can read the rendered files and their directories. The systemd
unit uses `ProtectSystem=strict` and grants write access only to the data
directory, the token sink directory and the template destination
directories. A token sink outside the data directory must be in a directory
that already exists and is writable by the agent user.

## Supported platforms

Red Hat Enterprise Linux 9 and 10 (and rebuilds), Debian 12 and 13, Ubuntu 22.04 and 24.04.

## Testing

The default scenario starts an in-memory OpenBao dev server inside the test
container, creates an AppRole and a secret, and checks that the agent renders,
proxies and re-renders the secret after rotation.

```bash
MOLECULE_DISTRO=ubuntu2404 molecule test
MOLECULE_DISTRO=ubuntu2404 molecule test -s invalid-config
```

---

Maintained by [Digitalis.io](https://digitalis.io). Support at [digitalis.io/contact](https://digitalis.io/contact).
