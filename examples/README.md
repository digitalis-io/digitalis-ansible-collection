# Examples

Each directory holds a playbook and an inventory. Credentials are read from
environment variables on the controller (see the comments in each playbook);
no secrets are stored in the repository.

| Example | Description |
|---------|-------------|
| [openbao-agent-secret](openbao-agent-secret/playbook.yml) | OpenBao server plus OpenBao Agent rendering a secret to a file |
| [prometheus-remote-write](prometheus-remote-write/playbook.yml) | Prometheus with scrape configs, file-based service discovery and `remote_write` |
| [prometheus-offline](prometheus-offline/playbook.yml) | Prometheus on a host without internet access (`prometheus_download_local`) |
| [postgres-cluster-single-node](postgres-cluster-single-node/playbook.yml) | One PostgreSQL node under Patroni with a local backup repository, a role and a database |
| [postgres-cluster-ha-s3](postgres-cluster-ha-s3/playbook.yml) | Three nodes with synchronous replication, S3 backups, HAProxy and pgAudit |
| [postgres-cluster-external-zookeeper](postgres-cluster-external-zookeeper/playbook.yml) | PostgreSQL nodes that use an existing ZooKeeper ensemble and Azure backups |
| [postgres-cluster-tls](postgres-cluster-tls/playbook.yml) | Three nodes with TLS from your own CA and a password protected Patroni API |

Check an example without touching any host:

```bash
ansible-playbook --syntax-check -i examples/prometheus-offline/inventory.yml examples/prometheus-offline/playbook.yml
```

`scripts/check-examples.py` runs this check for every example and also
verifies that each role variable used is documented in the role's
`meta/argument_specs.yml` and passes its type validation.
