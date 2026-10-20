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
| `openbao_agent_install` | bool | no | `true` | Install the OpenBao package, which provides the `bao` binary, by including the `openbao` role of this collection with `openbao_service_manage` set to `false`, so no OpenBao server service is managed. Set to `false` when `bao` is already installed (at `/usr/bin/bao`, the path used by the systemd unit). `openbao_version` and the OpenBao repository options are passed through to the `openbao` role. |
| `openbao_agent_user` | str | no | `openbao-agent` | System account the agent runs as. Created without a home directory and with `/bin/false` as shell. It owns the data directory, the credential files and any template destination directory the role creates. Keep it separate from the `openbao` server user so the agent and its `exec_command` commands cannot read server storage. Changing it rewrites the systemd unit and restarts the agent. |
| `openbao_agent_group` | str | no | `openbao-agent` | System group the agent runs as. Created by the role and used as group owner of the configuration directory, the `agent.hcl` file, copied templates, the data directory and credential files. Changing it rewrites the systemd unit and restarts the agent. |
| `openbao_agent_config_dir` | path | no | `/etc/openbao-agent` | Directory for `agent.hcl`, the credential files (`role_id`, `secret_id` or `token`) and the `templates/` subdirectory that receives templates given with `src`. Created as `root:<group>` with mode `0750`. It is passed to `bao agent -config=` in the systemd unit, so changing it rewrites the unit and restarts the agent. The old directory is not removed. |
| `openbao_agent_data_dir` | path | no | `/var/lib/openbao-agent` | Working directory of the agent. Holds the PID file `agent.pid` and, by default, the token sink. Created owned by the agent user with mode `0750`. It is the only path the systemd unit makes writable by default (`ProtectSystem=strict` with `ReadWritePaths`). Changing it rewrites the unit and the configuration and restarts the agent. |
| `openbao_agent_service_name` | str | no | `openbao-agent` | Name of the systemd unit, without the `.service` suffix. The role writes `/etc/systemd/system/<name>.service` and manages that unit. Changing it creates a new unit and leaves the previous one in place; stop and remove it separately. |
| `openbao_agent_service_enabled` | bool | no | `true` | Whether the unit is enabled to start at boot. Applied on every run with `systemd_service`, together with `daemon_reload`. |
| `openbao_agent_service_state` | str | no | `started` | State the role sets on the service at the end of each run. `started` keeps it running; `stopped` stops it; `restarted` restarts it on every run, so the result is never idempotent. Changes to the unit, `agent.hcl`, credential files or copied templates restart the agent through a handler, which is skipped when this is `stopped`. One of `started`, `stopped`, `restarted`. |
| `openbao_agent_address` | str | no | `""` | URL of the OpenBao server the agent connects to, for example `https://openbao.example.com:8200`. Required. Must start with `http://` or `https://`. Written to the `address` setting of the `vault` block in `agent.hcl`. The role fails before changing the host when it is empty or has no scheme. |
| `openbao_agent_ca_cert` | str | no | `""` | Path, on the managed host, to a PEM CA bundle used to verify the server certificate. The role does not copy the file; it must already exist and be readable by the agent user. Empty omits `ca_cert` from the configuration, so the system trust store is used. |
| `openbao_agent_tls_server_name` | str | no | `""` | Server name sent as SNI and used to verify the server certificate, for when it differs from the host name in `openbao_agent_address`. Empty omits the setting. |
| `openbao_agent_tls_skip_verify` | bool | no | `false` | Disable verification of the server TLS certificate. Written as `tls_skip_verify` in the `vault` block. Do not use in production: the agent then sends its credentials to any server that answers. Prefer `openbao_agent_ca_cert`. |
| `openbao_agent_retry_num_retries` | int | no | `12` | Number of times the agent retries a failed request to the server before giving up. Written as `num_retries` in the `retry` block of `agent.hcl`. Applies to requests made by the agent, including template rendering. See `openbao_agent_template_exit_on_retry_failure` for what happens when the retries run out. |
| `openbao_agent_log_level` | str | no | `info` | Verbosity of the agent log, written as `log_level` in `agent.hcl`. Output goes to the systemd journal. The value is validated against the listed choices by the argument spec before the role runs. Changing it restarts the agent. One of `trace`, `debug`, `info`, `warn`, `error`. |
| `openbao_agent_auth_method` | str | no | `approle` | Auto-auth method the agent uses to obtain a token. `approle` needs `openbao_agent_approle_role_id` and `openbao_agent_approle_secret_id`; `token_file` needs `openbao_agent_token`. Any other value is rejected before the host is changed. The credentials for the method not selected are ignored and not written. Changing the method rewrites `agent.hcl` and restarts the agent. One of `approle`, `token_file`. |
| `openbao_agent_auth_mount_path` | str | no | `auth/{{ openbao_agent_auth_method if openbao_agent_auth_method != 'token_file' else 'token' }}` | Mount path of the auth method. Defaults to `auth/approle` or `auth/token`. |
| `openbao_agent_approle_role_id` | str | no | `""` | AppRole role ID. Required, and must not be empty, when `openbao_agent_auth_method` is `approle`; ignored otherwise. Written to `<config_dir>/role_id` with mode `0600`, owned by the agent user. A change restarts the agent. Keep the value in ansible-vault or a secrets manager. |
| `openbao_agent_approle_secret_id` | str | no | `""` | AppRole secret ID. Required, and must not be empty, when `openbao_agent_auth_method` is `approle`; ignored otherwise. Written to `<config_dir>/secret_id` with mode `0600`, owned by the agent user. The agent does not delete the file after reading it, so the same secret ID is reused on restart; it must not be single-use or expire before the next run. A change restarts the agent. Keep the value in ansible-vault or a secrets manager. |
| `openbao_agent_token` | str | no | `""` | Token the agent reads with the `token_file` method. Required, and must not be empty, when `openbao_agent_auth_method` is `token_file`; ignored otherwise. Written to `<config_dir>/token` with mode `0600`, owned by the agent user. A change restarts the agent. Keep the value in ansible-vault or a secrets manager. |
| `openbao_agent_token_sink_enabled` | bool | no | `true` | Write the auto-auth token to a file so local processes can use it. The sink is configured as a `file` sink with the path and mode given by `openbao_agent_token_sink_path` and `openbao_agent_token_sink_mode`. Anyone who can read the file can act with the agent token, so restrict access with the mode and the directory permissions. |
| `openbao_agent_token_sink_path` | path | no | `{{ openbao_agent_data_dir }}/agent-token` | Path of the token sink file. Defaults to `<data_dir>/agent-token`. The role does not create the parent directory unless it is the data directory. When it is elsewhere, create it before the run and make it writable by the agent user; the systemd unit adds it to `ReadWritePaths` with a leading `-`, so a missing directory is not an error for systemd but the agent then cannot write the sink. Ignored when the sink is disabled. |
| `openbao_agent_token_sink_mode` | str | no | `0640` | File mode of the token sink as a four digit octal string, for example `0640`. Quote it so YAML does not read it as a number. Anything that is not `0` followed by three octal digits is rejected before the host is changed. Ignored when the sink is disabled. |
| `openbao_agent_listener_address` | str | no | `""` | Address for a local API proxy listener, for example `127.0.0.1:8100`. Empty disables it. |
| `openbao_agent_listener_allow_nonlocal` | bool | no | `false` | Allow a non-loopback listener address. The listener has no TLS and uses the agent token. |
| `openbao_agent_template_default_perms` | str | no | `0600` | File mode, as a four digit octal string such as `0600`, applied to rendered files of templates that do not set `perms`. Quote it so YAML does not read it as a number. Anything that is not `0` followed by three octal digits is rejected before the host is changed. |
| `openbao_agent_template_exit_on_retry_failure` | bool | no | `true` | Written as `exit_on_retry_failure` in the `template_config` block. When `true`, the agent exits if rendering a template fails after the configured retries (see `openbao_agent_retry_num_retries`), and systemd restarts it after 5 seconds. When `false`, the agent does not exit on this failure. |
| `openbao_agent_template_static_secret_render_interval` | str | no | `5m` | How often the agent re-renders templates that use static (non-leased) secrets, as a duration string such as `5m` or `30s`. Written as `static_secret_render_interval` in the `template_config` block. Lower values pick up changed secrets sooner at the cost of more requests to the server. |
| `openbao_agent_templates` | list of dict | no | `[]` | Templates to render. Each item needs `destination` and exactly one of `contents`, `src` or `source`. |
| `openbao_agent_extra_config` | str | no | `""` | Raw HCL appended unchanged at the end of `agent.hcl`, after the generated blocks. Use it for agent settings the role does not expose. The content is not validated by the role; invalid HCL or a block that duplicates a generated one makes the agent fail to start. A change restarts the agent. |

### `openbao_agent_templates` options

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `destination` | path | yes |  | Absolute path of the rendered file. |
| `contents` | str | no |  | Inline template. Tag it `!unsafe` so Ansible does not evaluate the agent template markers (double curly braces) and leaves them for the agent. |
| `src` | path | no |  | Controller file copied to `<config_dir>/templates/`. |
| `source` | path | no |  | Template file already on the host. |
| `perms` | str | no |  | File mode as a quoted four digit octal string such as `"0640"`; an unquoted value is read as a decimal number and rejected. Falls back to `openbao_agent_template_default_perms`. |
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
