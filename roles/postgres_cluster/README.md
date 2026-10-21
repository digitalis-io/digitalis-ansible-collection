<p align="center">
  <a href="https://digitalis.io">
    <img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/DigitalisDigital_DigitalisFullLogoGradient+-+medium.png" alt="Digitalis.io" width="300">
  </a>
</p>

<p align="center">
  <em>Built and maintained by <a href="https://digitalis.io">Digitalis.io</a></em>
</p>

# postgres_cluster

Deploy a highly available PostgreSQL cluster on Red Hat Enterprise Linux (and rebuilds), Debian and Ubuntu. The role installs PostgreSQL from the PGDG repositories and runs it under [Patroni](https://patroni.readthedocs.io), with [Apache ZooKeeper](https://zookeeper.apache.org) as the configuration store, [pgBackRest](https://pgbackrest.org) for backups and WAL archiving, and optional HAProxy, pgAudit and pgAgent.

```text
                       clients
                          |
              +-----------+-----------+
              | HAProxy on each node  |   :5000 -> primary   :5001 -> standbys
              +-----------+-----------+
                          |
     +--------------------+--------------------+
     |                    |                    |
+----+-----+         +----+-----+         +----+-----+
|  pg1     |         |  pg2     |         |  pg3     |
| Patroni  |<------->| Patroni  |<------->| Patroni  |     Patroni REST API :8008
| Postgres |  WAL    | Postgres |  WAL    | Postgres |     PostgreSQL        :5432
| ZooKeeper|<------->| ZooKeeper|<------->| ZooKeeper|     ZooKeeper         :2181
+----+-----+ stream  +----+-----+ stream  +----+-----+
     |                    |                    |
     +--------------------+--------------------+
                          |
              pgBackRest repository
        (S3, Azure, SMB share or a directory)
```

Patroni keeps one node as the primary and the others as streaming standbys. When the primary fails, a standby is promoted within the failover window (about 30 seconds by default) and the old primary rejoins as a standby, rewinding itself with `pg_rewind` when needed. HAProxy follows the change, so clients keep one address.

## Requirements

- ansible-core 2.15 or later on the controller
- Collections (installed with `digitalis.digitalis`, or manually):

  ```bash
  ansible-galaxy collection install community.postgresql community.crypto community.general ansible.posix
  ```

- Target hosts with systemd, root access (`become: true`), outbound HTTPS to the PostgreSQL package repositories and `archive.apache.org` (or mirrors, see below) and an IPv4 address on the default route
- Red Hat Enterprise Linux hosts need a subscription for the base repositories; the role adds the PGDG repository itself

### Supported platforms

CI runs Molecule on every scenario for Rocky Linux 9 and 10, Ubuntu and Debian (see [Testing](#testing)). Red Hat Enterprise Linux and AlmaLinux use the same Red Hat code path but are not in the CI matrix.

| OS | Versions |
|----|----------|
| Rocky Linux, AlmaLinux, Red Hat Enterprise Linux | 9, 10 |
| Ubuntu | 22.04 (jammy), 24.04 (noble), 26.04 (resolute) |
| Debian | 12 (bookworm), 13 (trixie) |

PostgreSQL 14, 15, 16 and 17 are supported. The default is 16.

### Network ports

Open these between the cluster nodes. Clients need only the PostgreSQL port, or the HAProxy ports.

| Port | Protocol | Used by | Who connects |
|------|----------|---------|--------------|
| 5432 | TCP | PostgreSQL | Other nodes (replication), clients, HAProxy |
| 8008 | TCP | Patroni REST API | Other nodes, HAProxy health checks, operators |
| 2181 | TCP | ZooKeeper clients | Patroni on every node |
| 2888, 3888 | TCP | ZooKeeper quorum and election | ZooKeeper nodes |
| 5000, 5001 | TCP | HAProxy write and read ports | Clients, when HAProxy is enabled |
| 22 | TCP | SSH | PostgreSQL nodes to each other, when `postgres_cluster_pgbackrest_backup_standby` is on |

## Quick start

Put the hosts in the `postgres_cluster` inventory group. Three nodes give you automatic failover:

```yaml
# inventory.yml
all:
  children:
    postgres_cluster:
      hosts:
        pg1.example.com:
        pg2.example.com:
        pg3.example.com:
```

```yaml
# playbook.yml
- name: Install a PostgreSQL cluster
  hosts: postgres_cluster
  become: true
  roles:
    - role: digitalis.digitalis.postgres_cluster
      vars:
        postgres_cluster_superuser_password: "{{ lookup('ansible.builtin.env', 'PG_SUPERUSER_PASSWORD') }}"
        postgres_cluster_replication_password: "{{ lookup('ansible.builtin.env', 'PG_REPLICATION_PASSWORD') }}"
        postgres_cluster_rewind_password: "{{ lookup('ansible.builtin.env', 'PG_REWIND_PASSWORD') }}"
```

```bash
ansible-galaxy collection install digitalis.digitalis
export PG_SUPERUSER_PASSWORD=... PG_REPLICATION_PASSWORD=... PG_REWIND_PASSWORD=...
ansible-playbook -i inventory.yml playbook.yml
```

The three passwords are required. The role refuses empty values, values shorter than eight characters and placeholders such as `changeme`. Keep them in ansible-vault or a secrets manager.

A first run takes a few minutes: it installs the packages, forms the ZooKeeper ensemble, bootstraps the first node, takes the first full backup and then adds the other nodes. Check the result on any node:

```console
$ patronictl list
+ Cluster: postgres (7376040310345619587) -+-----------+----+-----------+
| Member            | Host      | Role    | State     | TL | Lag in MB |
+-------------------+-----------+---------+-----------+----+-----------+
| pg1.example.com   | 10.0.1.11 | Leader  | running   |  1 |           |
| pg2.example.com   | 10.0.1.12 | Replica | streaming |  1 |         0 |
| pg3.example.com   | 10.0.1.13 | Replica | streaming |  1 |         0 |
+-------------------+-----------+---------+-----------+----+-----------+
```

`patronictl` is a shell alias that adds `-c /etc/patroni.yml`; it is available in login shells. A single host in the group gives a single node without failover, which is handy for development.

## Examples

Complete playbooks, checked in CI against the argument specification, are in [`examples/`](../../examples/README.md):

| Example | What it shows |
|---------|---------------|
| [postgres-cluster-single-node](../../examples/postgres-cluster-single-node/playbook.yml) | One node, local backups, a database and a role |
| [postgres-cluster-ha-s3](../../examples/postgres-cluster-ha-s3/playbook.yml) | Three nodes, synchronous replication, S3 backups, HAProxy, pgAudit |
| [postgres-cluster-external-zookeeper](../../examples/postgres-cluster-external-zookeeper/playbook.yml) | An existing ZooKeeper ensemble and Azure backups |
| [postgres-cluster-tls](../../examples/postgres-cluster-tls/playbook.yml) | TLS from your own CA and a password protected Patroni API |

### Tune PostgreSQL

`postgres_cluster_parameters` takes any `postgresql.conf` setting:

```yaml
postgres_cluster_parameters:
  max_connections: 300
  shared_buffers: 4GB
  effective_cache_size: 12GB
  work_mem: 16MB
  log_min_duration_statement: 500
```

Settings that Patroni manages for the whole cluster (`max_connections`, `max_wal_senders`, `max_worker_processes`, ...) are applied when the cluster is created. To change them later use `patronictl edit-config` (see [Day-2 operations](#day-2-operations)). Every other setting takes effect when Patroni reloads, which the role triggers; settings that need a restart show as *Pending restart* in `patronictl list`.

### Create databases and roles

```yaml
postgres_cluster_users:
  - name: app
    password: "{{ vault_app_password }}"
    priv: CONNECT                 # a privilege on the database in "db"
    db: orders
  - name: reporting
    password: "{{ vault_reporting_password }}"
    roles: [pg_read_all_data]     # membership in an existing role
  - name: migrator
    password: "{{ vault_migrator_password }}"
    role_attr_flags: CREATEDB
  - name: old_account
    state: absent                 # dropped
postgres_cluster_databases:
  - name: orders
    owner: app
```

Roles are created first, then databases (so an owner exists), then privileges. The role never drops anything that is only missing from the list.

### Allow clients to connect

Out of the box only local connections and the cluster nodes can connect. Add the networks your clients come from, one `pg_hba.conf` line each:

```yaml
postgres_cluster_hba:
  - host orders app 10.0.2.0/24 scram-sha-256
  - hostssl all reporting 10.0.3.0/24 scram-sha-256
```

When HAProxy is enabled, PostgreSQL sees the node's own address as the client for connections that came through HAProxy, so the rules must also match that address (`10.0.1.0/24` in the example network), not only the original client network.

### Back up to object storage

```yaml
postgres_cluster_pgbackrest_repo_type: s3
postgres_cluster_pgbackrest_s3_bucket: example-pgbackrest
postgres_cluster_pgbackrest_s3_region: eu-west-2
# Leave key and secret out to use the instance role of the node.
postgres_cluster_pgbackrest_s3_key: "{{ vault_s3_key }}"
postgres_cluster_pgbackrest_s3_key_secret: "{{ vault_s3_secret }}"
postgres_cluster_pgbackrest_retention_full: 7
```

For an S3-compatible service such as MinIO add `postgres_cluster_pgbackrest_s3_endpoint: minio.example.com` and `postgres_cluster_pgbackrest_s3_uri_style: path`. Use `azure` or `cifs` for Azure Blob Storage or an SMB share, and `posix` (the default) for a local directory. With several nodes a `posix` repository must be one directory that every node sees, such as an NFS mount; set `postgres_cluster_pgbackrest_repo_shared: true` to confirm it, or the role refuses to run. Use object storage in production. Clusters that share a bucket must use different `postgres_cluster_pgbackrest_stanza` values.

### Use TLS

Bring your own certificates, placed on every node before the role runs:

```yaml
postgres_cluster_ssl_enabled: true
postgres_cluster_ssl_cert: /etc/postgres_cluster/ssl/server.crt
postgres_cluster_ssl_key: /etc/postgres_cluster/ssl/server.key
postgres_cluster_ssl_ca: /etc/postgres_cluster/ssl/ca.crt
```

or let the role create a self-signed certificate for each node (tests and private networks only) with `postgres_cluster_ssl_self_signed: true`. Replication, `pg_rewind` and the Patroni REST API then use TLS, and HAProxy checks the REST API over HTTPS.

### Use an existing ZooKeeper ensemble

```yaml
postgres_cluster_manage_zookeeper: false
postgres_cluster_zookeeper_connect:
  - zk1.example.com:2181
  - zk2.example.com:2181
  - zk3.example.com:2181
```

Give each cluster that shares an ensemble its own `postgres_cluster_name`.

### Hosts without internet access

Point the role at internal mirrors: set `postgres_cluster_zookeeper_download_url` and `postgres_cluster_zookeeper_checksum` for ZooKeeper, and configure the PGDG repositories and the Python package index (for Patroni) in your mirror configuration before the role runs, or run the role once from a host with access to build a golden image.

## Variables

Generated from `meta/argument_specs.yml`; run `scripts/generate-docs.sh` to refresh.

<!-- BEGIN_ANSIBLE_DOCS -->

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `postgres_cluster_version` | int | no | `16` | Major PostgreSQL version to install, 14 to 17. The packages come from the PostgreSQL project repositories (PGDG), not the distribution. The version is part of the data directory (`<data_directory>/<version>/main`) and of the default pgBackRest stanza name, so changing it on a running cluster creates a new, empty cluster instead of upgrading; use a major upgrade procedure for that. One of `14`, `15`, `16`, `17`. |
| `postgres_cluster_name` | str | no | `postgres` | Patroni cluster name (the `scope`). Every node of one cluster uses the same value. It becomes the key prefix in ZooKeeper, so two clusters sharing one ZooKeeper ensemble need different names. Changing it on a running cluster makes the nodes form a new cluster. |
| `postgres_cluster_nodes` | list of str | no | `{{ groups['postgres_cluster'] \| default([]) }}` | Inventory hostnames of the PostgreSQL nodes. The role must run on every host in this list and only on those hosts. The default is the inventory group `postgres_cluster`. The order is not significant for PostgreSQL but fixes the ZooKeeper IDs, so append new nodes and do not reorder. |
| `postgres_cluster_primary` | str | no | `{{ postgres_cluster_nodes \| first \| default('') }}` | Node that bootstraps the cluster on the first run: it initialises the database (or restores the latest backup), creates the pgBackRest stanza and takes the first full backup before the other nodes start. After the cluster exists this setting has no effect and any node can be the primary. Defaults to the first host of `postgres_cluster_nodes`. |
| `postgres_cluster_address` | str | no | `{{ ansible_facts['default_ipv4']['address'] }}` | IP address of this node that the other nodes, clients and HAProxy use to reach PostgreSQL, the Patroni REST API and ZooKeeper. Set it per host (in host_vars) when the node has several interfaces or sits behind NAT. Defaults to the IPv4 address of the default route interface. |
| `postgres_cluster_user` | str | no | `postgres` | Operating system account that owns the data directory and runs PostgreSQL and Patroni. Created by the role if missing. It is also the name of the PostgreSQL superuser created by initdb. Changing it after the first run is not supported. |
| `postgres_cluster_group` | str | no | `postgres` | Primary group of `postgres_cluster_user`. Created by the role if missing. |
| `postgres_cluster_user_uid` | str | no | `""` | Fixed numeric UID for `postgres_cluster_user`, for hosts where the UID must match a network share or a policy. Empty lets the system choose. Only used when the account is created. |
| `postgres_cluster_user_groups` | list of str | no | `[]` | Additional groups for `postgres_cluster_user`, for example a group that may read the logs. The groups must already exist. They are appended to the existing memberships. |
| `postgres_cluster_data_directory` | path | no | `/pg_data` | Parent directory for the PostgreSQL data. The cluster lives in `<data_directory>/<version>/main`. Created with mode 0750 owned by `postgres_cluster_user`. Put it on its own volume. It must not be the parent of `postgres_cluster_wal_directory`. |
| `postgres_cluster_wal_directory` | path | no | `""` | Directory for the write-ahead log, passed to initdb as `--waldir`. Empty keeps the WAL inside the data directory. Use it to put WAL on a faster or separate volume. It only takes effect when the database is initialised, and must be an absolute path outside `postgres_cluster_data_directory`; the role refuses a path inside it. |
| `postgres_cluster_unix_socket_directory` | path | no | `/var/run/postgresql` | Directory of the PostgreSQL Unix socket. Used by Patroni, pgBackRest and the role's database tasks, which connect as `postgres_cluster_user` with peer authentication. Created if missing. |
| `postgres_cluster_log_directory` | path | no | `/var/log/postgresql` | Directory for the PostgreSQL log files, one file per weekday (`postgresql-Mon.log`, overwritten after a week). Created if missing. |
| `postgres_cluster_locale` | str | no | `en_US.UTF-8` | Locale for the cluster, passed to initdb, and the default `lc_collate` and `lc_ctype` of databases in `postgres_cluster_databases`. On Red Hat the language packs are installed; on Debian and Ubuntu the locale is generated. Use `C.UTF-8` to avoid installing anything. Only takes effect when the database is initialised. |
| `postgres_cluster_port` | int | no | `5432` | TCP port of PostgreSQL on every node. Also the port HAProxy forwards to and the port written to the pgBackRest configuration. |
| `postgres_cluster_auth_method` | str | no | `scram-sha-256` | Password authentication method used in `pg_hba.conf` for the replication, rewind and loopback rules the role writes, and the `password_encryption` setting for new passwords. Prefer `scram-sha-256`. `md5` is only for old clients that cannot do SCRAM. Rules in `postgres_cluster_hba` are written as given. One of `scram-sha-256`, `md5`. |
| `postgres_cluster_parameters` | dict | no | `{}` | PostgreSQL settings (`postgresql.conf` parameters) as a dictionary, for example `max_connections: 300` or `shared_buffers: 4GB`. Merged over the role's own settings, so a value given here wins. Written to the Patroni bootstrap section (used when the cluster is created) and to the local configuration, which Patroni applies on a reload. Settings Patroni controls cluster-wide (`max_connections`, `max_wal_senders`, `max_worker_processes`, `wal_level`, ...) take effect on a running cluster only after `patronictl edit-config`, followed by a restart when PostgreSQL says so (`patronictl list` shows Pending restart). Do not set `shared_preload_libraries` when `postgres_cluster_pgaudit_enabled` is true unless you include `pgaudit`. |
| `postgres_cluster_hba` | list of str | no | `[]` | Extra `pg_hba.conf` lines, appended after the role's own rules, in the usual format, for example `hostssl all app 10.0.0.0/24 scram-sha-256`. Without entries here only local connections and the cluster nodes can connect. Applied when Patroni reloads its configuration; no restart is needed. |
| `postgres_cluster_synchronous_replication` | bool | no | `true` | With two or more nodes, require a commit to be confirmed by one standby (`synchronous_commit = on`, `synchronous_standby_names = ANY 1 (...)`). This lowers the risk of losing commits on failover but does not remove it: Patroni promotes the standby with the least lag, which is not always one that confirmed the last commit. Writes block while no standby is reachable (for example with a two node cluster and one node down). Set to `false` for asynchronous replication, which keeps accepting writes but may lose the last transactions on failover. Ignored for a single node. |
| `postgres_cluster_patroni_port` | int | no | `8008` | Port of the Patroni REST API. HAProxy health checks and the role's own checks use it. The API listens on `postgres_cluster_address` only. |
| `postgres_cluster_patroni_venv` | path | no | `/opt/patroni` | Directory of the Python virtual environment holding Patroni. A virtual environment keeps Patroni away from the system Python, which distributions block from pip installs. The systemd unit points here, and `patroni` and `patronictl` are linked into `/usr/local/bin`. |
| `postgres_cluster_patroni_version` | str | no | `""` | Patroni version to install, for example `4.0.5`. Empty installs the latest release at the time of the first run and leaves it alone afterwards. Pin it in production and upgrade nodes one at a time. Needs Patroni 3.0 or later. |
| `postgres_cluster_patroni_ttl` | int | no | `30` | Seconds the leader lock lives in ZooKeeper before the cluster elects a new leader. Together with `loop_wait` and `retry_timeout` it sets the failover time; keep `loop_wait + 2 * retry_timeout <= ttl`. Applied when the cluster is created; change it afterwards with `patronictl edit-config`. |
| `postgres_cluster_patroni_loop_wait` | int | no | `10` | Seconds between Patroni's health loops. Applied when the cluster is created; change it afterwards with `patronictl edit-config`. |
| `postgres_cluster_patroni_retry_timeout` | int | no | `10` | Seconds Patroni retries ZooKeeper and PostgreSQL operations before it demotes the leader. Applied when the cluster is created; change it afterwards with `patronictl edit-config`. |
| `postgres_cluster_patroni_maximum_lag_on_failover` | int | no | `1048576` | Maximum replication lag, in bytes, of a standby that may be promoted. A standby further behind is not elected. Applied when the cluster is created; change it afterwards with `patronictl edit-config`. |
| `postgres_cluster_patroni_rest_user` | str | no | `""` | User name for HTTP basic authentication of the Patroni REST API's write operations (switchover, restart, reload). Read-only endpoints such as the HAProxy health checks stay open. Empty disables authentication. Set together with `postgres_cluster_patroni_rest_password`. |
| `postgres_cluster_patroni_rest_password` | str | no | `""` | Password for `postgres_cluster_patroni_rest_user`. Set together with the user. Written to `/etc/patroni.yml`. The API uses HTTP Basic authentication, so enable `postgres_cluster_ssl_enabled` as well, or the password crosses the network in clear text. |
| `postgres_cluster_patroni_rest_allowlist` | list of str | no | `[]` | Addresses and networks, for example `10.0.9.0/24`, that may reach the Patroni REST API in addition to the cluster nodes, which are always allowed. Empty allows every address. Set it to your administration hosts and load balancers: the API can change the cluster configuration and trigger failovers. HAProxy runs on the nodes and is covered by the node list; an external load balancer that checks `/primary` must be listed. |
| `postgres_cluster_ssl_enabled` | bool | no | `false` | Encrypt client, replication and Patroni REST API connections with TLS. The role then uses `hostssl` rules for replication and rewind, and HTTPS for the REST API. Needs a certificate and key at `postgres_cluster_ssl_cert` and `postgres_cluster_ssl_key`: either create them with `postgres_cluster_ssl_self_signed` or place them on the host before the role runs. Existing connections are not interrupted but Patroni must be restarted to start using TLS. |
| `postgres_cluster_ssl_self_signed` | bool | no | `false` | Create a private key and a self-signed certificate on each node (valid ten years, with the host name, the node address and 127.0.0.1 as names). Good for tests and private networks; clients cannot verify these certificates against a CA. Needs `postgres_cluster_ssl_enabled`. Existing files are left alone. |
| `postgres_cluster_ssl_cert` | path | no | `/etc/postgres_cluster/ssl/server.crt` | Path of the server certificate (PEM) on each node. Created when `postgres_cluster_ssl_self_signed` is true; otherwise it must exist before the role runs, or the role stops. Used by PostgreSQL and the Patroni REST API. Include intermediate certificates in the file. |
| `postgres_cluster_ssl_key` | path | no | `/etc/postgres_cluster/ssl/server.key` | Path of the private key (PEM) matching `postgres_cluster_ssl_cert`. Mode 0600 and owned by `postgres_cluster_user`, set by the role. |
| `postgres_cluster_ssl_ca` | path | no | `""` | Path of a CA bundle (PEM) on each node. Empty omits it. When set, PostgreSQL gets it as `ssl_ca_file`, the REST API as `cafile`, and `patronictl` uses it to verify the REST API certificate; the role does not create or copy the file. |
| `postgres_cluster_ssl_ciphers` | str | no | `HIGH:!aNULL` | OpenSSL cipher list for PostgreSQL TLS connections (`ssl_ciphers`). The default allows strong ciphers only. |
| `postgres_cluster_manage_zookeeper` | bool | no | `true` | Install and configure an Apache ZooKeeper ensemble on `postgres_cluster_zookeeper_nodes` as the cluster's distributed configuration store. Set to `false` to use an existing ensemble listed in `postgres_cluster_zookeeper_connect`; the role then installs no Java or ZooKeeper. |
| `postgres_cluster_zookeeper_nodes` | list of str | no | `{{ postgres_cluster_nodes }}` | Hosts that run ZooKeeper, a subset of `postgres_cluster_nodes`. Use 1 node for tests, 3 for production (it tolerates one failure) and an odd number in general. The position in the list is the ZooKeeper ID, so only append to it. Defaults to every node. |
| `postgres_cluster_zookeeper_connect` | list of str | no | `[]` | Client addresses of an existing ZooKeeper ensemble as `host:port`, for example `zk1.example.com:2181`. Required, and only used, when `postgres_cluster_manage_zookeeper` is `false`. |
| `postgres_cluster_zookeeper_version` | str | no | `3.9.6` | ZooKeeper release to download, for example `3.9.6`. Only used with `postgres_cluster_manage_zookeeper`. Changing it downloads the new archive but does not replace an install in `postgres_cluster_zookeeper_install_dir`: remove the directory and run the role to upgrade. |
| `postgres_cluster_zookeeper_download_url` | str | no | `https://archive.apache.org/dist/zookeeper/zookeeper-{{ postgres_cluster_zookeeper_version }}/apache-zookeeper-{{ postgres_cluster_zookeeper_version }}-bin.tar.gz` | URL of the ZooKeeper binary archive. The default is the Apache archive, which keeps old releases. Point it at an internal mirror for hosts without internet access. |
| `postgres_cluster_zookeeper_checksum` | str | no | `sha512:{{ postgres_cluster_zookeeper_download_url }}.sha512` | Checksum the downloaded archive must match, in the `algorithm:value` or `algorithm:url` form of `ansible.builtin.get_url`. The default fetches the SHA-512 file published next to the archive. Set to the checksum itself when you use a mirror. Empty disables the check, which is not recommended. |
| `postgres_cluster_zookeeper_install_dir` | path | no | `/opt/zookeeper` | Directory the ZooKeeper archive is extracted to. Owned by root. |
| `postgres_cluster_zookeeper_data_dir` | path | no | `/var/lib/zookeeper` | ZooKeeper data directory, holding the snapshots, transaction logs, `myid` file and logs. Owned by the `zookeeper` user. |
| `postgres_cluster_zookeeper_conf_dir` | path | no | `/etc/zookeeper` | Directory of `zoo.cfg`. |
| `postgres_cluster_zookeeper_client_port` | int | no | `2181` | Port Patroni uses to talk to ZooKeeper. ZooKeeper listens on `postgres_cluster_address` only. |
| `postgres_cluster_zookeeper_leader_port` | int | no | `2888` | Port ZooKeeper followers use to connect to the leader. Open it between the ZooKeeper nodes. |
| `postgres_cluster_zookeeper_election_port` | int | no | `3888` | Port ZooKeeper nodes use for leader election. Open it between the ZooKeeper nodes. |
| `postgres_cluster_zookeeper_user_uid` | str | no | `""` | Fixed numeric UID for the `zookeeper` account. Empty lets the system choose. Only used when the account is created. |
| `postgres_cluster_java_package` | str | no | `""` | Package that provides Java for ZooKeeper. Empty picks OpenJDK 17, or OpenJDK 21 on Debian 13 and Red Hat 10, where 17 is not packaged. |
| `postgres_cluster_pgbackrest_stanza` | str | no | `main_{{ postgres_cluster_version }}` | pgBackRest stanza name, the label of this cluster in the backup repository. The default includes the PostgreSQL version. Keep it unchanged for the life of the cluster: a new name starts a new, empty backup set. Clusters that share a bucket or repository must use different stanzas, or a new cluster finds the other one's backups and restores them. |
| `postgres_cluster_pgbackrest_repo_type` | str | no | `posix` | Where pgBackRest stores backups and archived WAL. `posix` is a directory on each node (`postgres_cluster_pgbackrest_repo_path`, which can be an NFS mount you manage); it is not shared, so with several nodes only the node that takes the backup holds them. `s3` and `azure` use object storage shared by all nodes and are the choice for production clusters. `cifs` mounts an SMB share. The settings of the chosen type are required and checked before the host is changed. One of `posix`, `s3`, `azure`, `cifs`. |
| `postgres_cluster_pgbackrest_repo_path` | path | no | `/var/lib/pgbackrest` | Repository directory for the `posix` type, or the mount point of the share for the `cifs` type. Created with mode 0750 owned by `postgres_cluster_user` for `posix`. Ignored for `s3` and `azure`. |
| `postgres_cluster_pgbackrest_repo_shared` | bool | no | `false` | Confirms that with several nodes the `posix` repository is one directory seen by all nodes, for example an NFS mount at `postgres_cluster_pgbackrest_repo_path`. The role refuses several nodes with a `posix` repository unless this is `true`, because a per-node directory has the stanza only on the first node and WAL archiving stops after a failover. Ignored for other types and for a single node. |
| `postgres_cluster_pgbackrest_retention_full` | int | no | `3` | Number of full backups to keep, with the WAL they need. Older backups are expired by the next backup run. The role takes only the first full backup; schedule later backups yourself, for example with cron or a systemd timer running `pgbackrest backup`. |
| `postgres_cluster_pgbackrest_backup_standby` | bool | no | `false` | Run backups on a standby to spare the primary (`backup-standby=y`). Needs at least two nodes and SSH access between the nodes as `postgres_cluster_user`, which the role sets up with an ed25519 key, `authorized_keys` and `known_hosts` entries; sshd must be running and allow the account. Also makes each node's pgBackRest configuration list its peers, so `pgbackrest check` contacts all nodes. |
| `postgres_cluster_pgbackrest_log_level` | str | no | `info` | pgBackRest file log level: `off`, `error`, `warn`, `info`, `detail`, `debug` or `trace`. Logs go to `/var/log/pgbackrest`. One of `off`, `error`, `warn`, `info`, `detail`, `debug`, `trace`. |
| `postgres_cluster_pgbackrest_archive_push_queue_max` | str | no | `5GB` | Maximum size of WAL waiting to be archived (`archive-push-queue-max`), for example `5GB`. When the repository is unreachable and the queue exceeds this, pgBackRest drops WAL to protect the primary's disk, which breaks point-in-time recovery until the next full backup. Raise it for long outages of the repository. |
| `postgres_cluster_pgbackrest_spool_path` | path | no | `/var/spool/pgbackrest` | Directory for the asynchronous WAL archive queue (`archive-async=y`). Created if missing. Keep it on a volume with room for `postgres_cluster_pgbackrest_archive_push_queue_max`. |
| `postgres_cluster_pgbackrest_s3_bucket` | str | no | `""` | S3 bucket for the repository. Required for the `s3` type. The role does not create the bucket. |
| `postgres_cluster_pgbackrest_s3_region` | str | no | `""` | AWS region, or the region name your S3-compatible service expects, for example `eu-west-2`. Required for the `s3` type. |
| `postgres_cluster_pgbackrest_s3_endpoint` | str | no | `""` | S3 endpoint host name. Empty uses `s3.<region>.amazonaws.com`. Set it for an S3-compatible service such as MinIO or Ceph, usually with `postgres_cluster_pgbackrest_s3_uri_style: path`. |
| `postgres_cluster_pgbackrest_s3_key` | str | no | `""` | S3 access key ID. Empty uses `postgres_cluster_pgbackrest_s3_key_type` (by default the instance role). Set together with the secret. |
| `postgres_cluster_pgbackrest_s3_key_secret` | str | no | `""` | S3 secret access key. Set together with the key. Written to `/etc/pgbackrest.conf` (mode 0600). Keep it in ansible-vault or a secrets manager. |
| `postgres_cluster_pgbackrest_s3_key_type` | str | no | `auto` | How pgBackRest finds S3 credentials when no key is set: `auto` uses the EC2 instance metadata role, `web-id` uses a web identity token. Ignored when `postgres_cluster_pgbackrest_s3_key` is set. One of `auto`, `web-id`. |
| `postgres_cluster_pgbackrest_s3_uri_style` | str | no | `host` | S3 URI style: `host` for AWS (`bucket.endpoint`), `path` for most S3-compatible services (`endpoint/bucket`). One of `host`, `path`. |
| `postgres_cluster_pgbackrest_s3_verify_tls` | bool | no | `true` | Verify the TLS certificate of the S3 endpoint. Set to `false` only for a test service with a self-signed certificate. |
| `postgres_cluster_pgbackrest_azure_account` | str | no | `""` | Azure storage account name. Required for the `azure` type. |
| `postgres_cluster_pgbackrest_azure_container` | str | no | `""` | Azure blob container for the repository. Required for the `azure` type. The role does not create it. |
| `postgres_cluster_pgbackrest_azure_key` | str | no | `""` | Azure shared key or SAS token, depending on `postgres_cluster_pgbackrest_azure_key_type`. Required for the `azure` type. Written to `/etc/pgbackrest.conf` (mode 0600). Keep it in ansible-vault or a secrets manager. |
| `postgres_cluster_pgbackrest_azure_key_type` | str | no | `shared` | Kind of Azure credential in `postgres_cluster_pgbackrest_azure_key`: `shared` for the account key, `sas` for a shared access signature. One of `shared`, `sas`, `auto`. |
| `postgres_cluster_pgbackrest_azure_endpoint` | str | no | `blob.core.windows.net` | Azure blob endpoint. Change it for sovereign clouds or an emulator. |
| `postgres_cluster_pgbackrest_azure_uri_style` | str | no | `host` | Azure URI style: `host` for the public cloud, `path` for emulators and some private endpoints. One of `host`, `path`. |
| `postgres_cluster_pgbackrest_azure_verify_tls` | bool | no | `true` | Verify the TLS certificate of the Azure endpoint. Set to `false` only for an emulator with a self-signed certificate. |
| `postgres_cluster_pgbackrest_cifs_src` | str | no | `""` | SMB share to mount at `postgres_cluster_pgbackrest_repo_path`, for example `//fileserver.example.com/pgbackups`. Required for the `cifs` type. The role installs `cifs-utils` and the extra kernel modules for `iocharset=utf8`, and mounts the share persistently in `/etc/fstab`. |
| `postgres_cluster_pgbackrest_cifs_username` | str | no | `""` | User name for the SMB share. Required for the `cifs` type. Stored with the password in a root-only credentials file. |
| `postgres_cluster_pgbackrest_cifs_password` | str | no | `""` | Password for the SMB share. Required for the `cifs` type. Keep it in ansible-vault or a secrets manager. |
| `postgres_cluster_pgaudit_enabled` | bool | no | `false` | Install pgAudit, add it to `shared_preload_libraries` and create the extension in the `postgres` database on the primary. The setting reaches PostgreSQL through Patroni, so a running cluster needs a restart (`patronictl restart`) after you enable it; create the extension in other databases yourself. |
| `postgres_cluster_pgaudit_packages` | list of str | no | `[]` | Packages that provide pgAudit. Empty picks the PGDG package for `postgres_cluster_version` (`pgaudit16_14`, `pgaudit17_15`, `pgaudit_16`, `pgaudit_17`) on Red Hat and `postgresql-<version>-pgaudit` on Debian and Ubuntu. |
| `postgres_cluster_pgaudit_config` | dict | no | `{"pgaudit.log": "ddl,role", "pgaudit.log_catalog": "on", "pgaudit.log_level": "log", "pgaudit.log_parameter": "on", "pgaudit.log_relation": "off", "pgaudit.log_statement_once": "off"}` | pgAudit settings as a dictionary of `pgaudit.*` parameters, written to the PostgreSQL configuration. The default logs DDL and role changes with parameters, without relation detail. Add `pgaudit.log: "ddl,role,write"` to log writes. The `pgaudit.log` value is a comma separated list of `read`, `write`, `function`, `role`, `ddl`, `misc`. |
| `postgres_cluster_pgagent_enabled` | bool | no | `false` | Install and run pgAgent, the job scheduler for PostgreSQL, on Red Hat family systems only (the Debian package ships no service). Creates a superuser role, the `pgagent` extension on the primary and a service on every node. The service only works on the primary, so after a failover it must be restarted on the new primary. |
| `postgres_cluster_pgagent_user` | str | no | `pgagent` | PostgreSQL role pgAgent connects as. Created as superuser on the primary, because jobs run with its privileges. |
| `postgres_cluster_pgagent_password` | str | no | `""` | Password of the pgAgent role. Required (8 characters or more) when pgAgent is enabled. Written to the pgAgent `.pgpass` file. Keep it in ansible-vault or a secrets manager. |
| `postgres_cluster_pgagent_database` | str | no | `postgres` | Database pgAgent connects to and where its `pgagent` extension lives. |
| `postgres_cluster_haproxy_enabled` | bool | no | `false` | Install HAProxy on every node and expose a write port that always reaches the primary and a read port that reaches the standbys, using Patroni's REST API for health checks. Clients then need no knowledge of failover. On Red Hat with SELinux enforcing the role sets the booleans and port labels HAProxy needs. |
| `postgres_cluster_haproxy_bind_address` | str | no | `*` | Address HAProxy's read and write ports listen on. `*` listens on all interfaces; use an address to limit exposure. |
| `postgres_cluster_haproxy_write_port` | int | no | `5000` | Port that routes to the current primary. |
| `postgres_cluster_haproxy_read_port` | int | no | `5001` | Port that routes to the standbys. When no standby is healthy the port refuses connections. |
| `postgres_cluster_haproxy_maxconn` | int | no | `200` | Maximum concurrent connections for the whole HAProxy process (`global maxconn`). |
| `postgres_cluster_haproxy_server_maxconn` | int | no | `1200` | Maximum concurrent connections HAProxy opens to one PostgreSQL node. Keep it at or below PostgreSQL's `max_connections`. |
| `postgres_cluster_haproxy_stats_listen` | str | no | `127.0.0.1:7000` | Address and port of HAProxy's statistics page, `host:port`. Bind it to loopback unless the network is trusted. |
| `postgres_cluster_haproxy_prometheus_enabled` | bool | no | `true` | Serve Prometheus metrics from HAProxy's built-in exporter at `/metrics`. |
| `postgres_cluster_haproxy_prometheus_listen_address` | str | no | `localhost:8405` | Address and port of the Prometheus exporter, `host:port`. Ignored when the exporter is disabled. |
| `postgres_cluster_databases` | list of dict | no | `[]` | Databases to create on the primary after the cluster is up. Each item needs `name`. Removed databases need `state: absent`; the role never drops a database that is merely missing from the list. |
| `postgres_cluster_users` | list of dict | no | `[]` | PostgreSQL roles to create on the primary after the cluster is up. Each item needs `name`. A role is created or updated; with `state: absent` it is dropped after databases and privileges are handled. Roles are not removed when missing from the list. |
| `postgres_cluster_users_no_log` | bool | no | `true` | Hide role tasks' arguments and results from the Ansible output, because they contain passwords. Set to `false` only when debugging with test data. |
| `postgres_cluster_superuser_password` | str | yes |  | Password of the PostgreSQL superuser, used by Patroni to manage the database. Required. Must be at least 8 characters and not a placeholder such as `changeme`; the role refuses to run otherwise. Written to `/etc/patroni.yml` (mode 0600). Keep it in ansible-vault or a secrets manager. Changing it later does not change the role inside a running cluster; change it with `ALTER ROLE` and then here. |
| `postgres_cluster_replication_password` | str | yes |  | Password of the `replicator` role that standbys use to stream WAL. Required, same rules as `postgres_cluster_superuser_password`. Written to `/etc/patroni.yml`. Keep it in ansible-vault or a secrets manager. |
| `postgres_cluster_rewind_password` | str | yes |  | Password of the `rewind` role Patroni uses for `pg_rewind` after a failover. Required, same rules as `postgres_cluster_superuser_password`. Written to `/etc/patroni.yml`. Keep it in ansible-vault or a secrets manager. |

### `postgres_cluster_databases` options

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `name` | str | yes |  | Database name. |
| `owner` | str | no |  | Owning role. Defaults to `postgres_cluster_user`. The role must exist, so create it in `postgres_cluster_users`; users are created before databases. |
| `lc_collate` | str | no |  | Collation. Defaults to `postgres_cluster_locale`. |
| `lc_ctype` | str | no |  | Character classification. Defaults to `postgres_cluster_locale`. |
| `encoding` | str | no |  | Encoding. Defaults to `UTF-8`. |
| `template` | str | no |  | Template database. Defaults to `template0`, which allows the locale and encoding above. |
| `state` | str | no |  | `present` creates the database, `absent` drops it with its data. Defaults to `present`. One of `present`, `absent`. |

### `postgres_cluster_users` options

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `name` | str | yes |  | Role name. |
| `password` | str | no |  | Password in clear text; PostgreSQL stores a hash. Without it the role has no password and cannot log in with one. |
| `role_attr_flags` | str | no |  | Comma separated role attributes, for example `CREATEDB,NOLOGIN`, `SUPERUSER` or `REPLICATION`. |
| `roles` | list of str | no |  | Roles this role becomes a member of. The roles must already exist. |
| `priv` | str | no |  | Privileges in the `postgresql_user` module format, for example `CONNECT` (a privilege on the database `db`) or `CONNECT/orders:SELECT,INSERT` (also on the table `orders`). Applied after the databases exist, in `db`. |
| `db` | str | no |  | Database that `priv` applies to. |
| `state` | str | no |  | `present` creates the role, `absent` drops it. Defaults to `present`. One of `present`, `absent`. |
<!-- END_ANSIBLE_DOCS -->

## How a run works

1. Checks the input and fails before changing anything when it is wrong (see [Troubleshooting](#troubleshooting)).
2. Creates the `postgres` and `zookeeper` accounts and installs the base packages.
3. Creates TLS certificates when asked to, installs Java and ZooKeeper and starts it.
4. Adds the PGDG repository, installs PostgreSQL, pgBackRest and, in a virtual environment, Patroni.
5. Writes `/etc/pgbackrest.conf` and `/etc/patroni.yml` and starts Patroni on `postgres_cluster_primary`, which initialises the database, or restores the latest backup if the repository already holds one.
6. Creates the pgBackRest stanza and takes the first full backup on that node, then starts Patroni on the other nodes, which clone themselves from the primary.
7. On the current primary: creates roles, databases and privileges and enables pgAudit.
8. Installs pgAgent and HAProxy when enabled.

The role is idempotent: a second run changes nothing. It never restarts PostgreSQL. Configuration changes reload Patroni, and a changed ZooKeeper configuration restarts ZooKeeper one node at a time; changes that need a restart are yours to schedule with `patronictl restart`, one node at a time.

### Tags

| Tag | Tasks |
|-----|-------|
| `postgres_cluster_prepare` | Accounts and base packages |
| `postgres_cluster_ssl`, `ssl` | Self-signed certificates and certificate checks |
| `postgres_cluster_zookeeper`, `zookeeper` | Java and ZooKeeper |
| `postgres_cluster_postgres`, `postgres` | Repositories and packages, Patroni installation |
| `postgres_cluster_pgbackrest`, `pgbackrest` | pgBackRest configuration, CIFS mount, SSH trust |
| `postgres_cluster_patroni`, `patroni` | Patroni configuration, service and cluster bootstrap |
| `postgres_cluster_users`, `postgres_cluster_databases`, `users`, `databases` | Roles, databases and privileges |
| `postgres_cluster_pgaudit`, `pgaudit` | pgAudit extension |
| `postgres_cluster_pgagent`, `pgagent` | pgAgent |
| `postgres_cluster_haproxy`, `haproxy` | HAProxy |

For example, to change only users and databases: `ansible-playbook playbook.yml --tags postgres_cluster_users,postgres_cluster_databases`. The input checks and the node address facts always run.

## Connecting applications

| Endpoint | Reaches | Use for |
|----------|---------|---------|
| `<any node>:5000` (HAProxy) | The primary | Reads and writes |
| `<any node>:5001` (HAProxy) | The standbys, round robin | Read-only queries |
| `<node>:5432` | That node | Administration; not failover-aware |

Without HAProxy, use a libpq multi-host connection string. PostgreSQL clients pick the writable node:

```text
postgresql://app@10.0.1.11:5432,10.0.1.12:5432,10.0.1.13:5432/orders?target_session_attrs=read-write
```

HAProxy runs on every node. Put a virtual IP, a load balancer or a DNS name with the three addresses in front of port 5000 so clients survive the loss of the node they connect to. Prometheus can scrape HAProxy on `localhost:8405/metrics` (configurable). Patroni also exposes metrics at `http://<node>:8008/metrics`.

## Day-2 operations

Run these on any node as root; `patronictl` reads `/etc/patroni.yml`.

| Task | Command |
|------|---------|
| Show the cluster | `patronictl list` |
| Planned switchover | `patronictl switchover --leader pg1.example.com --candidate pg2.example.com` |
| Restart one node (pending restart) | `patronictl restart postgres pg2.example.com` |
| Rebuild a broken standby | `patronictl reinit postgres pg3.example.com` |
| Change cluster-wide settings | `patronictl edit-config` |
| Stop automatic failover for maintenance | `patronictl pause` ... `patronictl resume` |
| Show the history of failovers | `patronictl history` |

`postgres` is the value of `postgres_cluster_name`.

**Add a node.** Add the host to the inventory group and run the playbook for the whole group. The new node clones itself from the primary. For a ZooKeeper node, append it to `postgres_cluster_zookeeper_nodes` and restart ZooKeeper on the existing nodes one at a time afterwards, because the member list changed.

**Replace a failed node.** Remove it from the cluster with `patronictl remove`, only if it will not come back; then provision a new host with the same inventory name and run the role.

**Rotate a database password.** Change the password with `ALTER ROLE`, then update the variable. The role does not change the passwords of `postgres`, `replicator` and `rewind` in a running cluster.

**Upgrade minor versions.** Update the packages on the standbys one at a time, restarting PostgreSQL with `patronictl restart`, then switch over and update the former primary. A major version upgrade is not automated: build a new cluster with a new `postgres_cluster_version` and `postgres_cluster_name` and move the data with logical replication or `pg_upgrade`.

### Backups

The role takes the first full backup only. Schedule the rest yourself, on one node (the one that holds the repository for the `posix` type), for example with cron:

```yaml
- name: Schedule pgBackRest backups
  ansible.builtin.cron:
    name: "pgbackrest {{ item.type }}"
    user: postgres
    hour: "{{ item.hour }}"
    minute: "0"
    weekday: "{{ item.weekday }}"
    job: "pgbackrest --stanza=main_16 backup --type={{ item.type }}"
  loop:
    - { type: full, hour: 1, weekday: "0" }
    - { type: diff, hour: 1, weekday: "1-6" }
  when: inventory_hostname == groups['postgres_cluster'][0]
```

Check the repository with `sudo -u postgres pgbackrest info` and `sudo -u postgres pgbackrest --stanza=main_16 check`. With `postgres_cluster_pgbackrest_backup_standby`, a backup run on any node reads from a standby.

### Recovery

**Rebuild a lost cluster from the latest backup.** If every node and the ZooKeeper state are lost, recreate the hosts (or empty `<data_directory>/<version>/main` on one node), make sure the backup repository is reachable and run the role again. The role finds the backup in the repository, writes a Patroni configuration with `method: pgbackrest` and the first node restores it instead of running `initdb`. The other nodes then clone from it. This path is covered by the `restore` Molecule scenario. If ZooKeeper still holds the old cluster, remove its state first: `zkCli.sh deleteall /service/<postgres_cluster_name>` (or `patronictl remove` while Patroni still runs).

**Point-in-time recovery.** Pause failover, stop Patroni on all nodes, restore on one node and let the others rebuild from it:

```bash
patronictl pause
systemctl stop patroni                     # on every node
sudo -u postgres pgbackrest --stanza=main_16 --delta --type=time \
  --target="2026-01-15 09:30:00+00" --target-action=promote restore   # on one node
patronictl remove postgres                 # while ZooKeeper is up, answer the prompts
systemctl start patroni                    # on the restored node first
patronictl reinit postgres <other-node>    # then on the others
```

Rehearse this on a copy before you need it.

## Security notes

- Passwords are required, checked and kept out of the Ansible output: tasks that handle them use `no_log` and `diff: false`, and `/etc/patroni.yml`, `/etc/pgbackrest.conf` and the pgAgent password file are mode 0600. Do not set `postgres_cluster_users_no_log: false` outside tests.
- The default `pg_hba.conf` allows only local peer authentication, password logins on loopback and the cluster nodes' replication and rewind accounts. Everything else is up to `postgres_cluster_hba`.
- Authentication defaults to `scram-sha-256`. `md5` exists for old clients only.
- The ZooKeeper archive is verified against the SHA-512 file Apache publishes. Do not disable the check.
- The Patroni REST API accepts changes (configuration, restart, switchover) from any host that can reach it unless you set `postgres_cluster_patroni_rest_user` and `postgres_cluster_patroni_rest_password`, and limit the callers with `postgres_cluster_patroni_rest_allowlist`. A caller that can change the configuration can run commands as the PostgreSQL user, so treat port 8008 like an administration port. Basic authentication needs TLS to be safe.
- The role does not manage a firewall. ZooKeeper listens without authentication on the node addresses. Restrict ports 2181, 2888 and 3888 to the cluster nodes.
- With `postgres_cluster_pgbackrest_backup_standby` the PostgreSQL account of every node can log in to every other node with an ed25519 key. The account is given the password field `*` (no password login) for that.

## Testing

The role is tested with [Molecule](https://ansible.readthedocs.io/projects/molecule/) in Docker. Each scenario has a Gherkin `.feature` file under `molecule/<scenario>/features/` that describes the behaviour in plain language, and a `verify.yml` that asserts it.

| Scenario | What it proves |
|----------|----------------|
| `default` | One node: services, Patroni, ZooKeeper, HAProxy, roles and databases, privileges, backups, WAL archiving, pgAudit and idempotence |
| `cluster` | Three nodes: ensemble and replication health, synchronous replication, data through HAProxy, standby backups over SSH, a planned switchover and the loss of the leader |
| `tls` | TLS everywhere, an authenticated Patroni API, md5 passwords, a separate WAL directory, non-default ports and locale |
| `restore` | A cluster that lost its data and its ZooKeeper state is rebuilt from the backup |
| `invalid-config` | 24 invalid inputs are rejected with a message that names the setting, before the host is changed |

```bash
pip install ansible-core molecule 'molecule-plugins[docker]' docker
cd roles/postgres_cluster
MOLECULE_DISTRO=debian13 molecule test                    # default scenario
MOLECULE_DISTRO=ubuntu2404 molecule test -s cluster
molecule test -s invalid-config
```

`MOLECULE_DISTRO` is one of `rockylinux9`, `rockylinux10`, `ubuntu2204`, `ubuntu2404`, `ubuntu2604`, `debian12`, `debian13`. The scenarios need the Docker daemon and take 5 to 15 minutes each. CI runs every scenario on every distribution; see `.github/workflows/postgres-cluster-molecule.yml`.

The scenarios set `ansible_become_method: su`: on some Docker hosts (for example Colima) PAM cannot authenticate root inside privileged containers, which breaks `sudo`. Real hosts are not affected.

## Troubleshooting

| Symptom | Cause and fix |
|---------|---------------|
| `postgres_cluster_superuser_password must be set to a secret ...` | A required password is missing, shorter than 8 characters or a placeholder. Set all three passwords. |
| `postgres_cluster_nodes must list the inventory hostnames ...` | The host is not in the `postgres_cluster` group (or in `postgres_cluster_nodes`). The role runs only on cluster members. |
| `Wait for the first node to become the primary` times out | Patroni could not start. Run `journalctl -u patroni` on the primary node; typical causes are an unreachable ZooKeeper (port 2181), a wrong `postgres_cluster_address` or a full disk. |
| `Create the pgBackRest stanza` or `Read the pgBackRest repository` fails | The repository is not reachable. Check the credentials and the bucket or share, then `sudo -u postgres pgbackrest info`. |
| A standby stays in `creating replica` | It cannot reach the primary on 5432, or `pg_hba.conf` does not allow its address. With the `posix` repository it falls back to a base backup, which takes time for large databases. |
| Writes hang with two nodes | Synchronous replication waits for a standby. Bring the node back, or set `postgres_cluster_synchronous_replication: false` and accept possible loss on failover. |
| `Pending restart` in `patronictl list` | A setting changed that needs a restart. `patronictl restart <cluster> <member>`, one node at a time. |
| Clients cannot log in through HAProxy | The client address PostgreSQL sees is the node's, not the client's. Add a `postgres_cluster_hba` rule for the node network. |
| Backups fail with `unable to find standby cluster` | `postgres_cluster_pgbackrest_backup_standby` is on but SSH between the nodes fails. Test `sudo -u postgres ssh <other node address> true`. |

Useful logs: `journalctl -u patroni`, `/var/log/postgresql/`, `/var/log/pgbackrest/`, `journalctl -u zookeeper` and `/var/lib/zookeeper/logs/`.

## Migrating from ar-postgres-cluster

This role replaces the standalone `ar-postgres-cluster` role. Every variable now has the prefix `postgres_cluster_` and is documented and type-checked.

> The role has not been run against clusters that `ar-postgres-cluster` created. Test the migration on a copy of the inventory first, and read the behaviour changes below before you run it on production.

| ar-postgres-cluster | postgres_cluster |
|---------------------|------------------|
| `pg_version` | `postgres_cluster_version` |
| `postgres_package_version` | removed; the latest minor release of the major version is installed |
| `patroni_cluster_name` | `postgres_cluster_name` |
| `patroni_nodes`, `postgres_servers` | `postgres_cluster_nodes` (default: group `postgres_cluster`, was `tag_Role_postgres`) |
| `patroni_primary` | `postgres_cluster_primary` |
| `hostvars[...].private_ip_address` | `postgres_cluster_address` (default: the default IPv4 address) |
| `patroni_superuser_password`, `patroni_replication_password`, `patroni_rewind_password` | `postgres_cluster_superuser_password`, `postgres_cluster_replication_password`, `postgres_cluster_rewind_password` (required, no default) |
| `patroni_port` | `postgres_cluster_patroni_port` |
| `patroni_parameters` | `postgres_cluster_parameters` |
| `postgresql_global_config_options` | removed; put the settings in `postgres_cluster_parameters` |
| `patroni_hba` | `postgres_cluster_hba` |
| `patroni_listen_address`, `fqdn`, `internal_domain`, `dns_domain` | removed; use `postgres_cluster_address` |
| `patroni_rest_user`, `patroni_rest_password` | `postgres_cluster_patroni_rest_user`, `postgres_cluster_patroni_rest_password` |
| `patroni_ssl_self_signed`, `patroni_ssl_cert`, `patroni_ssl_key`, `patroni_ssl_ca` | `postgres_cluster_ssl_self_signed`, `postgres_cluster_ssl_cert`, `postgres_cluster_ssl_key`, `postgres_cluster_ssl_ca`; TLS now needs `postgres_cluster_ssl_enabled: true` |
| `postgres_data_directory` | `postgres_cluster_data_directory` |
| `postgres_wal_archive_directory` | `postgres_cluster_wal_directory` |
| `postgresql_user`, `postgresql_group` | `postgres_cluster_user`, `postgres_cluster_group` |
| `postgres_user_uid`, `postgres_groups` | `postgres_cluster_user_uid`, `postgres_cluster_user_groups`; the `digitalis` group is no longer created |
| `postgresql_unix_socket_directories` (list) | `postgres_cluster_unix_socket_directory` (one path) |
| `postgresql_auth_method` | `postgres_cluster_auth_method` (default `scram-sha-256` on every system) |
| `postgresql_databases`, `postgresql_users`, `postgres_users_no_log` | `postgres_cluster_databases`, `postgres_cluster_users`, `postgres_cluster_users_no_log` |
| `postgresql_enable_pgaudit`, `postgresql_paudit_config`, `postgresql_paudit_packages` | `postgres_cluster_pgaudit_enabled`, `postgres_cluster_pgaudit_config`, `postgres_cluster_pgaudit_packages` |
| `postgresql_pgagent` (dict) | `postgres_cluster_pgagent_enabled`, `_user`, `_password`, `_database` |
| `zookeeper_servers` | `postgres_cluster_zookeeper_nodes` |
| `zookeeper_version`, `zookeeper_download_url`, `zookeeper_install_dir`, `zookeeper_data_dir`, `zookeeper_conf_dir` | the same names with the `postgres_cluster_` prefix |
| `zookeeper_node_id`, `zookeeper_servers_use_inventory_hostname` | removed; the ID is the position in `postgres_cluster_zookeeper_nodes` |
| `java_version` | `postgres_cluster_java_package` |
| `pgbackrest_s3_bucket`, `pgbackrest_s3_access_key`, `pgbackrest_s3_secret_key`, `aws_region` | `postgres_cluster_pgbackrest_s3_bucket`, `_s3_key`, `_s3_key_secret`, `_s3_region`; set `postgres_cluster_pgbackrest_repo_type: s3` |
| `pgbackrest_azure_*` | `postgres_cluster_pgbackrest_azure_*`; set `postgres_cluster_pgbackrest_repo_type: azure` |
| `pgbackrest_backup_cifs_src`, `pgbackrest_user`, `pgbackrest_password` | `postgres_cluster_pgbackrest_cifs_src`, `_cifs_username`, `_cifs_password`; set `postgres_cluster_pgbackrest_repo_type: cifs` |
| `pgbackrest_backup_standby` | `postgres_cluster_pgbackrest_backup_standby` (default is now `false`) |
| `pgbackrest_log_level`, `postgres_archive_push_queue_max`, `postgres_spool_path` | `postgres_cluster_pgbackrest_log_level`, `_archive_push_queue_max`, `_spool_path` |
| `enable_haproxy`, `haprox_maxconn` | `postgres_cluster_haproxy_enabled`, `postgres_cluster_haproxy_maxconn` |
| `haproxy_prometheus_enabled`, `haproxy_prometheus_listen_address` | `postgres_cluster_haproxy_prometheus_enabled`, `postgres_cluster_haproxy_prometheus_listen_address` |

Behaviour changes to plan for:

- Patroni runs from a virtual environment in `/opt/patroni` (symlinked into `/usr/local/bin`), not from the system Python.
- A configuration change reloads Patroni; the old role restarted it, which stopped PostgreSQL on every node at once.
- The first full backup is taken once. The old role took a full backup on every run.
- `pg_hba.conf` rules for replication use `host` when TLS is off and `hostssl` when it is on. The old role always wrote `hostssl`.
- The `rewind` account may connect from the cluster nodes, and local connections use peer authentication.
- ZooKeeper is downloaded from `archive.apache.org` and verified against its published checksum. The ID in `myid` is now the position in the node list; an ensemble created by the old role used IDs derived from the node addresses, so keep the old IDs in mind before you re-run the role on it.
- Passwords have no default. The old role shipped `changeme`.

## License

Apache License 2.0. See [LICENSE](../../LICENSE).

---

This project is maintained by [Digitalis.io](https://digitalis.io). For support, visit [digitalis.io/contact](https://digitalis.io/contact).
