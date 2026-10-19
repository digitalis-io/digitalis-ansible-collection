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
  roles:
    - role: digitalis.digitalis.rabbitmq
      vars:
        rabbitmq_version: "4.2.5"
        rabbitmq_admin_user: admin
        rabbitmq_admin_password: "s3cur3p4ss"
        rabbitmq_plugins: "rabbitmq_management,rabbitmq_prometheus"
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
  roles:
    - role: digitalis.digitalis.rabbitmq
      vars:
        rabbitmq_version: "4.2.5"
        rabbitmq_erlang_cookie: "CHANGE_THIS_TO_A_RANDOM_SECRET"
        rabbitmq_cluster_members:
          - rabbit@node1.example.com
          - rabbit@node2.example.com
          - rabbit@node3.example.com
        rabbitmq_ssl:
          key: /etc/rabbitmq/server.key
          cert: /etc/rabbitmq/server.crt
          ca: /etc/rabbitmq/ca.pem
          password: ""
          internode_encryption: true
        rabbitmq_admin_user: admin
        rabbitmq_admin_password: "s3cur3p4ss"
```

### Queues with dead-letter queues

```yaml
- hosts: rabbitmq
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
  roles:
    - role: digitalis.digitalis.rabbitmq
      vars:
        rabbitmq_use_haproxy: true
        rabbitmq_admin_user: admin
        rabbitmq_admin_password: "s3cur3p4ss"
```

## Variable Reference

### Core

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `rabbitmq_version` | string | `"4.2.5"` | RabbitMQ version to install |
| `rabbitmq_daemon` | string | `rabbitmq-server` | systemd service name |
| `rabbitmq_state` | string | `started` | Service state: `started`, `stopped` |
| `rabbitmq_enabled` | bool | `true` | Enable service at boot |
| `rabbitmq_log_level` | string | `info` | Log level: `debug`, `info`, `warning`, `error` |
| `rabbitmq_listen_address` | string | `0.0.0.0` | Interface RabbitMQ listens on |
| `rabbitmq_use_longname` | bool | `false` | Use fully-qualified node names |
| `rabbitmq_plugins` | list | `[rabbitmq_management, rabbitmq_prometheus]` | Enabled plugins; must include `rabbitmq_management` |

### Networking / Protocol Tuning

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `rabbitmq_channel_max` | int | `128` | Maximum channels per connection |
| `rabbitmq_frame_max` | int | `131072` | Maximum frame size in bytes |
| `rabbitmq_initial_frame_max` | int | `4096` | Initial frame size negotiated on connect |

### Installation (Debian/Ubuntu only)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `rabbitmq_apt_arch` | string | auto-detected | Apt architecture (`amd64`, `arm64`). Derived from `ansible_architecture`. |
| `rabbitmq_apt_key_url` | string | RabbitMQ key URL | URL to the RabbitMQ team OpenPGP key |
| `rabbitmq_apt_key_path` | string | `/usr/share/keyrings/com.rabbitmq.team.gpg` | Path to write the signing key |
| `rabbitmq_apt_repos` | list | RabbitMQ Erlang + server repos | List of APT repos (`url`, `type`) |
| `rabbitmq_erlang_version_map` | dict | per-distro versions | Maps codename → pinned Erlang version string |
| `rabbitmq_erlang_version` | string | auto from map | Erlang version installed (derived from `rabbitmq_erlang_version_map`) |
| `rabbitmq_erlang_packages` | list | 17 erlang-* packages | Erlang packages to install |

### Clustering

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `rabbitmq_erlang_cookie` | string | `""` | Shared secret for cluster node authentication. Required for clusters; not written when empty. |
| `rabbitmq_cluster_members` | list | `[]` | List of cluster nodes, e.g. `rabbit@node1.example.com`. Empty = standalone. |
| `rabbitmq_cluster_name` | string | unset | Optional cluster name (e.g. `rabbit.example.com`) |
| `rabbitmq_cluster_tags` | dict | `{}` | Key/value tags applied to cluster nodes |

### TLS / SSL

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `rabbitmq_ssl` | dict | unset | TLS configuration. When defined, enables TLS. |
| `rabbitmq_ssl.key` | string | — | Path to private key, e.g. `/etc/rabbitmq/server.key` |
| `rabbitmq_ssl.cert` | string | — | Path to certificate, e.g. `/etc/rabbitmq/server.crt` |
| `rabbitmq_ssl.ca` | string | — | Path to CA certificate, e.g. `/etc/rabbitmq/ca.pem` |
| `rabbitmq_ssl.password` | string | `""` | Private key password (empty = no password) |
| `rabbitmq_ssl.internode_encryption` | bool | `false` | Enable TLS for inter-node cluster traffic |
| `rabbitmq_ssl_ciphers` | list | 12 GCM ciphers | Allowed TLS cipher suites |

### Admin User

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `rabbitmq_admin_user` | string | `admin` | Admin username created by the role |
| `rabbitmq_admin_password` | string | `""` | Admin password. Required; the role fails if unset. |
| `rabbitmq_admin_permissions` | list | full access on `/` | Permissions granted to the admin user |

### Users

```yaml
rabbitmq_users:
  - name: guest          # required — RabbitMQ username
    state: absent        # present (default) or absent
  - name: appuser
    password: "appp4ss"  # required when state: present
    vhost: /myapp        # vhost to grant permissions on (default: /)
    configure_priv: ".*" # configure permission regex (default: .*)
    read_priv: ".*"      # read permission regex (default: .*)
    write_priv: ".*"     # write permission regex (default: .*)
    tags: monitoring     # RabbitMQ tags (e.g. administrator, monitoring)
```

The default removes the built-in `guest` account:

```yaml
rabbitmq_users:
  - name: guest
    state: absent
```

### Virtual Hosts

```yaml
rabbitmq_vhosts:
  - name: /myapp         # vhost path (required)
    state: present       # present (default) or absent
    tracing: false       # enable message tracing (default: false)
```

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `rabbitmq_vhosts` | list | `[]` | Virtual hosts to create or remove |

### Queues

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `rabbitmq_queues` | list | `[]` | Queues to create. Empty = no queues created. |
| `rabbitmq_queue_defaults` | dict | quorum queue settings | Default arguments merged into every queue |

```yaml
rabbitmq_queues:
  - name: orders          # queue name (required)
    create_dlq: true      # also create orders-dlq (default: false)
    durable: true         # survive broker restart (default: omit)
    max_length: 100000    # max messages (default: omit)
    max_priority: 10      # enable priority queue 0-255 (default: omit)
    vhost: /myapp         # vhost (default: /)
    leader: node1.fqdn    # node to create on (default: ansible_fqdn)
    state: present        # present or absent (default: present)
    arguments: {}         # extra x-arguments merged with rabbitmq_queue_defaults
```

Default queue arguments applied to all queues:

```yaml
rabbitmq_queue_defaults:
  x-queue-type: quorum
  x-delivery-limit: 20
  x-quorum-initial-group-size: 3
```

### OAuth2 / OIDC

Setting `rabbitmq_oauth2_issuer` enables the OAuth2 backend; `client_id` and `client_secret` are required. TLS verification is on by default (`rabbitmq_oauth2_verify_peer`). Optional: `rabbitmq_oauth2_token_url`, `rabbitmq_oauth2_jwks_url`, `rabbitmq_oauth2_ca_cert`, `rabbitmq_oauth2_scopes`, `rabbitmq_oauth2_resource_server_id`.

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `rabbitmq_oauth2_issuer` | string | unset | OIDC issuer URL, e.g. `https://keycloak.example.com/realms/myrealm` |
| `rabbitmq_oauth2_client_id` | string | unset | OAuth2 client ID |
| `rabbitmq_oauth2_client_secret` | string | unset | OAuth2 client secret |

### HAProxy

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `rabbitmq_use_haproxy` | bool | `false` | Install and configure HAProxy in front of RabbitMQ |

### Backups

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `rabbitmq_backup_cronjob.enabled` | bool | `false` | Enable automated backup cron job |
| `rabbitmq_backup_cronjob.schedule` | string | `0 0 * * *` | Cron schedule (daily at midnight) |
| `rabbitmq_backup_cronjob.directory` | string | `/var/backups/rabbitmq` | Backup directory (mode 0700) |
| `rabbitmq_backup_cronjob.retention_days` | int | `7` | Days to keep definition exports |

```yaml
rabbitmq_backup_cronjob:
  enabled: true
  schedule: "0 2 * * *"
  command: "/usr/local/bin/rabbitmqadmin --username={{ rabbitmq_admin_user }} --password={{ rabbitmq_admin_password }} -H localhost -P 15672 export /tmp/cluster.backup-$(date +'%s').json"
```

### Sysctl Tuning

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `rabbitmq_sysctl` | dict | network/fd tuning | Kernel parameters applied via `ansible.posix.sysctl`. Skipped in Docker. |

```yaml
rabbitmq_sysctl:
  fs.file-max: 200000
  net.core.rmem_max: 16777216
  net.core.wmem_max: 16777216
  net.core.somaxconn: 4096
  net.ipv4.tcp_keepalive_time: 60
  net.ipv4.tcp_keepalive_intvl: 10
  net.ipv4.tcp_keepalive_probes: 3
  net.ipv4.ip_local_port_range: "1024 65535"
```

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
