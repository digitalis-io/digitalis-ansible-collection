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

Generated from `meta/argument_specs.yml`; run `scripts/generate-docs.sh` to refresh.

<!-- BEGIN_ANSIBLE_DOCS -->

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `openbao_agent_install` | bool | no | `true` | Install the OpenBao package with the openbao role. |
| `openbao_agent_user` | str | no | `openbao-agent` | User the agent runs as. |
| `openbao_agent_group` | str | no | `openbao-agent` | Group the agent runs as. |
| `openbao_agent_config_dir` | path | no | `/etc/openbao-agent` | Directory for the agent configuration, credentials and copied templates. |
| `openbao_agent_data_dir` | path | no | `/var/lib/openbao-agent` | Agent working directory for the PID file and token sink. |
| `openbao_agent_service_name` | str | no | `openbao-agent` | Name of the systemd unit. |
| `openbao_agent_service_enabled` | bool | no | `true` | Enable the agent service at boot. |
| `openbao_agent_service_state` | str | no | `started` | State of the agent service. One of `started`, `stopped`, `restarted`. |
| `openbao_agent_address` | str | no | `""` | URL of the OpenBao server. Required. |
| `openbao_agent_ca_cert` | str | no | `""` | Path on the host to a CA bundle used to verify the server. |
| `openbao_agent_tls_server_name` | str | no | `""` | SNI host name used when connecting to the server. |
| `openbao_agent_tls_skip_verify` | bool | no | `false` | Disable TLS verification. Do not use in production. |
| `openbao_agent_retry_num_retries` | int | no | `12` | Number of retries for failed requests to the server. |
| `openbao_agent_log_level` | str | no | `info` | Agent log level. One of `trace`, `debug`, `info`, `warn`, `error`. |
| `openbao_agent_auth_method` | str | no | `approle` | Auto-auth method. One of `approle`, `token_file`. |
| `openbao_agent_auth_mount_path` | str | no |  | Mount path of the auth method. Defaults to `auth/approle` or `auth/token`. |
| `openbao_agent_approle_role_id` | str | no | `""` | AppRole role ID. Required for the approle method. |
| `openbao_agent_approle_secret_id` | str | no | `""` | AppRole secret ID. Required for the approle method. |
| `openbao_agent_token` | str | no | `""` | Token for the token_file method. |
| `openbao_agent_token_sink_enabled` | bool | no | `true` | Write the auto-auth token to a file sink. |
| `openbao_agent_token_sink_path` | path | no |  | Token sink path. Defaults to `<data_dir>/agent-token`. |
| `openbao_agent_token_sink_mode` | str | no | `0640` | Octal file mode of the token sink. |
| `openbao_agent_listener_address` | str | no | `""` | Address for a local API proxy listener, for example `127.0.0.1:8100`. Empty disables it. |
| `openbao_agent_listener_allow_nonlocal` | bool | no | `false` | Allow a non-loopback listener address. The listener has no TLS and uses the agent token. |
| `openbao_agent_template_default_perms` | str | no | `0600` | Mode for rendered files when a template item does not set perms. |
| `openbao_agent_template_exit_on_retry_failure` | bool | no | `true` | Exit the agent when template rendering exhausts its retries. |
| `openbao_agent_template_static_secret_render_interval` | str | no | `5m` | How often non-leased secrets are re-rendered. |
| `openbao_agent_templates` | list of dict | no | `[]` | Templates to render. Each item needs `destination` and exactly one of `contents`, `src` or `source`. |
| `openbao_agent_extra_config` | str | no | `""` | Raw HCL appended to the agent configuration. |

### `openbao_agent_templates` options

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `destination` | path | yes |  | Absolute path of the rendered file. |
| `contents` | str | no |  | Inline template, tagged `!unsafe` so Ansible leaves the `{{ }}` markers for the agent. |
| `src` | path | no |  | Controller file copied to `<config_dir>/templates/`. |
| `source` | path | no |  | Template file already on the host. |
| `perms` | str | no |  | File mode. Falls back to `openbao_agent_template_default_perms`. |
| `error_on_missing_key` | bool | no |  | Fail rendering on missing keys. |
| `backup` | bool | no |  | Keep the previous render. |
| `create_dest_dirs` | bool | no |  | Let the agent create parent directories. |
| `left_delimiter` | str | no |  | Left template delimiter. |
| `right_delimiter` | str | no |  | Right template delimiter. |
| `wait_min` | str | no |  | Minimum render quiescence timer, for example `5s`. |
| `wait_max` | str | no |  | Maximum render quiescence timer, for example `10s`. |
| `exec_command` | raw | no |  | Command run after a changed render, as a string or a list of arguments. |
| `exec_timeout` | str | no |  | Command timeout. Requires `exec_command`. Falls back to `30s`. |
<!-- END_ANSIBLE_DOCS -->

With `openbao_agent_install: true` the [openbao](../openbao/README.md) role
installs the package, so `openbao_version` and its repository variables apply.
That role never touches the `openbao` server service when called from here.

Missing destination directories are created for the agent user. Existing
directories are not changed, so the agent user must be able to write to them.
Destinations directly in `/`, `/etc`, `/usr`, `/var` or `/boot` are refused;
use a subdirectory. Set `openbao_agent_group` to the group of the consuming
service so it can read the rendered files and their directories. The systemd
unit uses `ProtectSystem=strict` and grants write access only to the data
directory, the token sink directory and the template destination
directories. A token sink outside the data directory must be in a directory
that already exists and is writable by the agent user.

See also the complete playbook in [examples/openbao-agent-secret](../../examples/openbao-agent-secret/playbook.yml).

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
