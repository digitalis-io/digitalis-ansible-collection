# Examples

Each directory holds a playbook and an inventory. Credentials are read from
environment variables on the controller (see the comments in each playbook);
no secrets are stored in the repository.

| Example | Description |
|---------|-------------|
| [openbao-agent-secret](openbao-agent-secret/playbook.yml) | OpenBao server plus OpenBao Agent rendering a secret to a file |
| [prometheus-remote-write](prometheus-remote-write/playbook.yml) | Prometheus with scrape configs, file-based service discovery and `remote_write` |
| [prometheus-offline](prometheus-offline/playbook.yml) | Prometheus on a host without internet access (`prometheus_download_local`) |

Check an example without touching any host:

```bash
ansible-playbook --syntax-check -i examples/prometheus-offline/inventory.yml examples/prometheus-offline/playbook.yml
```

`scripts/check-examples.py` runs this check for every example and also
verifies that each role variable used is documented in the role's
`meta/argument_specs.yml` and passes its type validation.
