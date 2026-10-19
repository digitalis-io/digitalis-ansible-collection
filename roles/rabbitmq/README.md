<p align="center">
  <a href="https://digitalis.io">
    <img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/DigitalisDigital_DigitalisFullLogoGradient+-+medium.png" alt="Digitalis.IO" width="300">
  </a>
</p>

<p align="center">
  <em>Built and maintained by <a href="https://digitalis.io">Digitalis.IO</a></em>
</p>

# rabbitmq

Ansible role to install, configure, and manage RabbitMQ on RHEL/Rocky Linux and Debian/Ubuntu systems. Supports single-node and clustered deployments, TLS, OAuth2/OIDC authentication, queue management with dead-letter queues, and optional HAProxy integration.

## Requirements

- Ansible Core >= 2.15
- Collections (installed with `digitalis.digitalis`, or manually as below):
  - `community.rabbitmq`
  - `ansible.posix`

```bash
ansible-galaxy collection install community.rabbitmq ansible.posix
```

## Supported Platforms

| OS | Versions |
|----|----------|
| Rocky Linux | 9, 10 |
| Ubuntu | 22.04 (Jammy), 24.04 (Noble), 26.04 (Resolute) |
| Debian | 12 (Bookworm), 13 (Trixie) |

> **Note (Debian/Ubuntu — ARM64):** The RabbitMQ Erlang repository only publishes `amd64` packages. The role sets `rabbitmq_apt_arch` dynamically. On ARM64 hosts, Erlang must be provided by an alternative source (e.g., distro packages or a custom repo). Set `rabbitmq_apt_arch: amd64` only on x86_64.

## Quick Start

```bash
# Install the collection (pulls in community.rabbitmq and ansible.posix)
ansible-galaxy collection install digitalis.digitalis
```

```yaml
# playbook.yml
- hosts: rabbitmq
  become: true
  roles:
    - role: digitalis.digitalis.rabbitmq
      vars:
        rabbitmq_admin_password: "changeme"
```

```bash
ansible-playbook -i inventory playbook.yml
```

## Usage Examples

### Single-node with management UI

```yaml
- hosts: rabbitmq
  become: true
  roles:
    - role: digitalis.digitalis.rabbitmq
      vars:
        rabbitmq_version: "4.2.5"
        rabbitmq_admin_user: admin
        rabbitmq_admin_password: "s3cur3p4ss"
        rabbitmq_plugins:
          - rabbitmq_management
          - rabbitmq_prometheus
        rabbitmq_vhosts:
          - name: /myapp
            state: present
        rabbitmq_users:
          - name: guest
            state: absent
          - name: appuser
            password: "appp4ss"
            vhost: /myapp
            configure_priv: ".*"
            read_priv: ".*"
            write_priv: ".*"
            tags: monitoring
```

### Three-node cluster with TLS

```yaml
- hosts: rabbitmq
  become: true
  roles:
    - role: digitalis.digitalis.rabbitmq
      vars:
        rabbitmq_version: "4.2.5"
        rabbitmq_erlang_cookie: "CHANGE_THIS_TO_A_RANDOM_SECRET"
        rabbitmq_cluster_members:
          - node1
          - node2
          - node3
        rabbitmq_ssl:
          key: /etc/rabbitmq/server.key
          cert: /etc/rabbitmq/server.crt
          ca: /etc/rabbitmq/ca.pem
          internode_encryption: true
        rabbitmq_admin_user: admin
        rabbitmq_admin_password: "s3cur3p4ss"
```

### Queues with dead-letter queues

```yaml
- hosts: rabbitmq
  become: true
  roles:
    - role: digitalis.digitalis.rabbitmq
      vars:
        rabbitmq_admin_user: admin
        rabbitmq_admin_password: "s3cur3p4ss"
        rabbitmq_queues:
          - name: orders
            create_dlq: true
            durable: true
            vhost: /myapp
          - name: notifications
            create_dlq: false
            max_length: 10000
            max_priority: 10
            vhost: /myapp
        rabbitmq_queue_defaults:
          x-queue-type: quorum
          x-delivery-limit: 20
          x-quorum-initial-group-size: 3
```

### OAuth2/OIDC authentication

```yaml
- hosts: rabbitmq
  become: true
  roles:
    - role: digitalis.digitalis.rabbitmq
      vars:
        rabbitmq_admin_user: admin
        rabbitmq_admin_password: "s3cur3p4ss"
        rabbitmq_oauth2_issuer: "https://keycloak.example.com/realms/myrealm"
        rabbitmq_oauth2_client_id: mgt_api_client
        rabbitmq_oauth2_client_secret: "my-client-secret"
        rabbitmq_queues:
          - name: events
            create_dlq: true
            vhost: /
```

When `rabbitmq_oauth2_issuer`, `rabbitmq_oauth2_client_id`, and `rabbitmq_oauth2_client_secret` are all defined, the role authenticates to the RabbitMQ API via OAuth2 bearer token rather than basic auth.

### With HAProxy

```yaml
- hosts: rabbitmq
  become: true
  roles:
    - role: digitalis.digitalis.rabbitmq
      vars:
        rabbitmq_use_haproxy: true
        rabbitmq_admin_user: admin
        rabbitmq_admin_password: "s3cur3p4ss"
```

## Variable Reference

Generated from `meta/argument_specs.yml`; run `scripts/generate-docs.sh` to refresh.

<!-- BEGIN_ANSIBLE_DOCS -->

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `rabbitmq_version` | str | no | `4.2.5` | RabbitMQ version to install. |
| `rabbitmq_admin_version` | str | no | `2.29.0` | Version of `rabbitmqadmin` installed for the backup job. |
| `rabbitmq_daemon` | str | no | `rabbitmq-server` | Name of the systemd service. |
| `rabbitmq_state` | str | no | `started` | State passed to the systemd module, for example `started` or `stopped`. |
| `rabbitmq_enabled` | bool | no | `true` | Enable the service at boot. |
| `rabbitmq_log_level` | str | no | `info` | Default log level, for example `debug`, `info`, `warning` or `error`. |
| `rabbitmq_listen_address` | str | no | `0.0.0.0` | Interface the AMQP and Prometheus listeners bind to. |
| `rabbitmq_nodename` | str | no | `rabbit@{{ ansible_hostname }}` | Node name used by `rabbitmqctl` and the community.rabbitmq modules. Override when `ansible_hostname` does not match the running node. |
| `rabbitmq_use_longname` | bool | no | `false` | Use fully-qualified node names. |
| `rabbitmq_domain` | str | no |  | Domain appended to cluster member names when `rabbitmq_use_longname` is enabled. Falls back to `internal`. |
| `rabbitmq_plugins` | list of str | no | `['rabbitmq_management', 'rabbitmq_prometheus']` | Plugins to enable. Must include `rabbitmq_management`, which the queue and virtual host tasks use. |
| `rabbitmq_amqp_port` | int | no | `5672` | AMQP port. |
| `rabbitmq_amqp_ssl_port` | int | no | `5671` | AMQP TLS port, used when `rabbitmq_ssl` is set. |
| `rabbitmq_management_port` | int | no | `15672` | Management UI and API port. |
| `rabbitmq_management_ssl_port` | int | no | `15671` | Management UI and API TLS port, used when `rabbitmq_ssl` is set. |
| `rabbitmq_management_listen_address` | str | no | `127.0.0.1` | Address the management listener binds to. Set to `0.0.0.0` to expose it externally. |
| `rabbitmq_prometheus_port` | int | no | `15692` | Prometheus endpoint port. |
| `rabbitmq_prometheus_ssl_port` | int | no | `15691` | Prometheus endpoint TLS port, used when `rabbitmq_ssl` is set. |
| `rabbitmq_channel_max` | int | no | `128` | Maximum channels per connection. |
| `rabbitmq_frame_max` | int | no | `131072` | Maximum frame size in bytes. |
| `rabbitmq_initial_frame_max` | int | no | `4096` | Initial frame size in bytes negotiated on connect. |
| `rabbitmq_file_limits` | int | no | `65535` | Open file limit (`LimitNOFILE`) of the systemd unit. |
| `rabbitmq_quorum_commands_soft_limit` | int | no | `64` | Soft limit of in-flight quorum queue commands. |
| `rabbitmq_disk_free_limit` | float | no |  | Free disk space limit relative to total RAM. Ignored when `rabbitmq_disk_free_absolute` is set. Falls back to `2.0`. |
| `rabbitmq_disk_free_absolute` | str | no |  | Free disk space limit as an absolute value, for example `10GB`. Takes precedence over `rabbitmq_disk_free_limit`. |
| `rabbitmq_password_hashing` | str | no |  | Password hashing module. Falls back to `rabbit_password_hashing_sha512`. |
| `rabbitmq_queue_leader_locator` | str | no |  | Queue leader placement strategy. Falls back to `balanced`. |
| `rabbitmq_load_definitions_file` | path | no |  | Path to a definitions file on the target host that RabbitMQ loads at boot. |
| `rabbitmq_home` | path | no |  | Home directory of the `rabbitmq` user, where the Erlang cookie is written. Falls back to `/var/lib/rabbitmq`. |
| `rabbitmq_apt_arch` | str | no | `{{ ansible_architecture \| replace('x86_64', 'amd64') \| replace('aarch64', 'arm64') }}` | APT architecture (Debian and Ubuntu only). |
| `rabbitmq_apt_key_url` | str | no | `https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA` | URL of the RabbitMQ team OpenPGP key (Debian and Ubuntu only). |
| `rabbitmq_apt_key_path` | path | no | `/usr/share/keyrings/com.rabbitmq.team.gpg` | Path the signing key is written to (Debian and Ubuntu only). |
| `rabbitmq_apt_repos` | list of dict | no |  | APT repositories to configure (Debian and Ubuntu only). Defaults to the RabbitMQ Erlang and server mirrors, see `defaults/main.yml`. |
| `rabbitmq_erlang_version_map` | dict | no |  | Maps the distribution codename to the pinned Erlang package version (Debian and Ubuntu only). See `defaults/main.yml` for the shipped map. |
| `rabbitmq_erlang_version` | str | no | `{{ rabbitmq_erlang_version_map.get(ansible_distribution_release, '1:27.2-1') }}` | Erlang package version to install (Debian and Ubuntu only). |
| `rabbitmq_erlang_packages` | list of str | no |  | Erlang packages to install (Debian and Ubuntu only). Defaults to the 17 `erlang-*` packages RabbitMQ requires, pinned to `rabbitmq_erlang_version`. |
| `rabbitmq_erlang_cookie` | str | no | `""` | Shared secret for cluster node authentication. Required for clusters and not written when empty. |
| `rabbitmq_cluster_members` | list of str | no | `[]` | Cluster node names, for example `node1`. Empty creates a standalone node. |
| `rabbitmq_cluster_name` | str | no |  | Cluster name, for example `rabbit.example.com`. |
| `rabbitmq_cluster_tags` | dict | no | `{}` | Key/value tags applied to the cluster. |
| `rabbitmq_cluster_partition_handling` | str | no |  | Network partition handling strategy. Falls back to `pause_minority`. One of `pause_minority`, `pause_if_all_down`, `autoheal`, `ignore`. |
| `rabbitmq_cluster_partition_handling_pause_if_all_down` | str | no |  | Recovery strategy used when `rabbitmq_cluster_partition_handling` is `pause_if_all_down`. Falls back to `autoheal`. |
| `rabbitmq_ssl` | dict | no |  | TLS configuration. When defined, TLS is enabled and the plain-text AMQP listener is disabled. |
| `rabbitmq_ssl_ciphers` | list of str | no |  | Allowed TLS cipher suites. Defaults to twelve AES-GCM suites, see `defaults/main.yml`. |
| `rabbitmq_oauth2_issuer` | str | no |  | OIDC issuer URL. Setting it enables the OAuth2 backend and requires `rabbitmq_oauth2_client_id` and `rabbitmq_oauth2_client_secret`. |
| `rabbitmq_oauth2_client_id` | str | no |  | OAuth2 client ID. |
| `rabbitmq_oauth2_client_secret` | str | no |  | OAuth2 client secret. |
| `rabbitmq_oauth2_jwks_url` | str | no |  | JWKS endpoint URL. Discovered from the issuer when unset. |
| `rabbitmq_oauth2_token_url` | str | no |  | Token endpoint URL. Falls back to `<issuer>/protocol/openid-connect/token`. |
| `rabbitmq_oauth2_resource_server_id` | str | no | `rabbitmq` | Resource server identifier. |
| `rabbitmq_oauth2_scopes` | str | no | `openid profile rabbitmq.tag:administrator` | Space-separated scopes requested by the management UI. |
| `rabbitmq_oauth2_verify_peer` | bool | no | `true` | Verify the identity provider TLS certificate. |
| `rabbitmq_oauth2_ca_cert` | path | no |  | CA certificate used to verify the identity provider. |
| `rabbitmq_erl_ssl_path` | str | no | `/usr/lib/erlang/lib/ssl-11.2.6/ebin` | Fallback Erlang SSL library path written to `rabbitmq-env.conf` when TLS is enabled and the path cannot be detected. |
| `rabbitmq_admin_user` | str | no | `admin` | Name of the administrator account created by the role. |
| `rabbitmq_admin_password` | str | no | `""` | Password of the administrator account. Required, the role fails when empty. |
| `rabbitmq_admin_permissions` | list of dict | no | `[{'vhost': '/', 'configure_priv': '.*', 'read_priv': '.*', 'write_priv': '.*'}]` | Permissions granted to the administrator account. |
| `rabbitmq_users` | list of dict | no | `[{'name': 'guest', 'state': 'absent'}]` | Users to manage. The default removes the built-in `guest` account. |
| `rabbitmq_vhosts` | list of dict | no | `[]` | Virtual hosts to manage. |
| `rabbitmq_queue_defaults` | dict | no | `{"x-queue-type": "quorum", "x-delivery-limit": 20, "x-quorum-initial-group-size": 3}` | Arguments merged into every queue in `rabbitmq_queues`. |
| `rabbitmq_queues` | list of dict | no | `[]` | Queues to manage. Requires the management plugin. |
| `rabbitmq_use_haproxy` | bool | no | `false` | Install and configure HAProxy in front of RabbitMQ. |
| `rabbitmq_haproxy_amqp_port` | int | no | `5670` | HAProxy frontend port for AMQP. |
| `rabbitmq_haproxy_amqp_ssl_port` | int | no | `5673` | HAProxy frontend port for AMQP over TLS. |
| `rabbitmq_haproxy_mgmt_port` | int | no | `15670` | HAProxy frontend port for the management UI. |
| `rabbitmq_haproxy_mgmt_ssl_port` | int | no | `15673` | HAProxy frontend port for the management UI over TLS. |
| `rabbitmq_haproxy_stats_port` | int | no | `1936` | HAProxy statistics port. |
| `rabbitmq_haproxy_stats_address` | str | no | `127.0.0.1` | Address the HAProxy statistics page binds to. |
| `rabbitmq_haproxy_log_address` | str | no | `127.0.0.1` | Address HAProxy sends logs to. |
| `rabbitmq_haproxy_group` | str | no | `rabbitmq` | Inventory group whose hosts become HAProxy backends. |
| `rabbitmq_backup_cronjob` | dict | no | `{'enabled': False, 'schedule': '0 0 * * *', 'directory': '/var/backups/rabbitmq', 'retention_days': 7}` | Scheduled export of the cluster definitions with `rabbitmqadmin`. When overriding, set every key, because the defaults below apply only to the whole dict. |
| `rabbitmq_sysctl` | dict | no | `{"fs.file-max": 200000, "net.core.rmem_max": 16777216, "net.core.wmem_max": 16777216, "net.core.somaxconn": 4096, "net.ipv4.tcp_keepalive_time": 60, "net.ipv4.tcp_keepalive_intvl": 10, "net.ipv4.tcp_keepalive_probes": 3, "net.ipv4.ip_local_port_range": "1024 65535"}` | Kernel parameters applied with `ansible.posix.sysctl`. Skipped on Docker hosts. |

### `rabbitmq_apt_repos` options

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `url` | str | yes |  | Repository URL. |
| `type` | str | no |  | Repository kind. One of `erlang`, `server`. |

### `rabbitmq_ssl` options

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `key` | path | yes |  | Path to the private key on the target host. |
| `cert` | path | yes |  | Path to the certificate on the target host. |
| `ca` | path | yes |  | Path to the CA certificate on the target host. |
| `verify` | str | no | `verify_none` | Peer verification mode for AMQP clients. One of `verify_none`, `verify_peer`. |
| `versions` | raw | no | `tlsv1.2` | TLS protocol version or list of versions. |
| `internode_encryption` | bool | no | `false` | Encrypt inter-node cluster traffic. |
| `password` | str | no |  | Private key password. Accepted for compatibility, currently unused. |

### `rabbitmq_admin_permissions` options

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `vhost` | str | yes |  | Virtual host the permissions apply to. |
| `configure_priv` | str | no | `.*` | Configure permission regular expression. |
| `read_priv` | str | no | `.*` | Read permission regular expression. |
| `write_priv` | str | no | `.*` | Write permission regular expression. |

### `rabbitmq_users` options

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `name` | str | yes |  | Username. |
| `password` | str | no |  | Password. Required when `state` is `present`. |
| `state` | str | no | `present` | Create or remove the user. One of `present`, `absent`. |
| `vhost` | str | no | `/` | Virtual host to grant permissions on. |
| `configure_priv` | str | no | `.*` | Configure permission regular expression. |
| `read_priv` | str | no | `.*` | Read permission regular expression. |
| `write_priv` | str | no | `.*` | Write permission regular expression. |
| `tags` | str | no |  | RabbitMQ user tags as a comma-separated string, for example `administrator,monitoring`. Lists are not supported. |
| `update_password` | str | no | `on_create` | Whether to reset the password of an existing user. One of `always`, `on_create`. |

### `rabbitmq_vhosts` options

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `name` | str | yes |  | Virtual host name, for example `/app`. |
| `state` | str | no | `present` | Create or remove the virtual host. One of `present`, `absent`. |
| `tracing` | bool | no | `false` | Enable message tracing. |

### `rabbitmq_queues` options

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `name` | str | yes |  | Queue name. |
| `state` | str | no | `present` | Create or remove the queue. One of `present`, `absent`. |
| `vhost` | str | no | `/` | Virtual host of the queue. |
| `create_dlq` | bool | no | `false` | Also create a `<name>-dlq` dead-letter queue and route rejected messages to it. |
| `durable` | bool | no |  | Keep the queue across broker restarts. |
| `max_length` | int | no |  | Maximum number of messages. |
| `max_priority` | int | no |  | Maximum priority, 0 to 255, enabling a priority queue. |
| `leader` | str | no |  | Node the API calls are sent to. Defaults to the management listen address, or the inventory hostname when that is `0.0.0.0`. |
| `arguments` | dict | no |  | Extra queue arguments merged over `rabbitmq_queue_defaults`. |
| `dlq_arguments` | dict | no |  | Extra arguments for the `<name>-dlq` queue, merged over `rabbitmq_queue_defaults`. |

### `rabbitmq_backup_cronjob` options

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `enabled` | bool | no | `false` | Install the backup job. |
| `schedule` | str | no | `0 0 * * *` | Cron schedule. |
| `directory` | path | no | `/var/backups/rabbitmq` | Directory the exports are written to (mode `0700`). |
| `retention_days` | int | no | `7` | Days to keep exports. |
<!-- END_ANSIBLE_DOCS -->

## Tags

Run subsets of the role using tags:

| Tag | What it runs |
|-----|-------------|
| `os_config` | File descriptor limits, sysctl |
| `system_config` | systemd service override |
| `config` | rabbitmq.conf, rabbitmq-env.conf, Erlang cookie, TLS config |
| `plugins` | enabled_plugins |
| `vhosts` | Virtual host creation/removal |
| `users` | User creation/removal |
| `queues` | Queue creation/removal |
| `backups` | Backup cron job |
| `haproxy` | HAProxy install and config |
| `rabbitmqadmin` | Download `rabbitmqadmin` CLI |

```bash
# Only apply config changes, no package install
ansible-playbook playbook.yml --tags config

# Only manage users and vhosts
ansible-playbook playbook.yml --tags users,vhosts
```

## About Digitalis

[Digitalis](https://digitalis.io) is a cloud-native technology services company specializing in data engineering, DevOps, and digital transformation. With deep expertise in Apache Kafka, Apache Cassandra, Kubernetes, RabbitMQ, and many more open-source technologies, Digitalis helps organizations design, deploy, and operate resilient data infrastructure at scale.

This project is maintained by [Digitalis.io](https://digitalis.io). For support, visit [digitalis.io/contact](https://digitalis.io/contact).

## License

Apache License 2.0 — see the [LICENSE](LICENSE) file for details.
