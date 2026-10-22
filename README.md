<p align="center">
  <a href="https://digitalis.io">
    <img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/DigitalisDigital_DigitalisFullLogoGradient+-+medium.png" alt="Digitalis.io" width="300">
  </a>
</p>

<p align="center">
  <em>Built and maintained by <a href="https://digitalis.io">Digitalis.io</a></em>
</p>

# Digitalis.io Ansible Collection

Ansible roles maintained by Digitalis.io for Red Hat Enterprise Linux, Debian and Ubuntu.

## Requirements

- ansible-core 2.16 or later on the controller
- Target hosts running a supported distribution (see below) with systemd
- For `openbao_agent`: a reachable OpenBao server and an AppRole (or token)
  allowed to read the secrets you render

## Installation

```bash
ansible-galaxy collection install digitalis.digitalis
# or
ansible-galaxy collection install git+https://github.com/digitalis-io/digitalis-ansible-collection.git
```

To pin it in a project, add it to `requirements.yml` and run
`ansible-galaxy collection install -r requirements.yml`:

```yaml
collections:
  - name: digitalis.digitalis
    version: ">=0.1.0"
```

## Roles

| Role | Description |
|------|-------------|
| [openbao](roles/openbao/README.md) | Install the OpenBao server package from the upstream repository |
| [openbao_agent](roles/openbao_agent/README.md) | Install and run OpenBao Agent to render secrets to files |
| [rabbitmq](roles/rabbitmq/README.md) | Install and configure RabbitMQ, including clustering, TLS and queues |
| [prometheus](roles/prometheus/README.md) | Install and configure the Prometheus monitoring system |
| [postgres_cluster](roles/postgres_cluster/README.md) | Highly available PostgreSQL with Patroni, ZooKeeper, pgBackRest and HAProxy |

Variable reference, defaults and examples are in each role's README. Complete
playbooks are in [examples](examples/README.md).

## Supported platforms

| Distribution | Versions |
|--------------|----------|
| Red Hat Enterprise Linux and rebuilds (Rocky, Alma) | 9, 10 |
| Debian | 12 (bookworm), 13 (trixie) |
| Ubuntu | 22.04 (jammy), 24.04 (noble), 26.04 (resolute, `postgres_cluster` only) |

## Testing

Each role has Molecule scenarios under `roles/<role>/molecule/`, driven by
`MOLECULE_DISTRO` (`rockylinux9`, `rockylinux10`, `ubuntu2204`, `ubuntu2404`,
`ubuntu2604`, `debian12`, `debian13`):

```bash
pip install ansible-core molecule 'molecule-plugins[docker]' docker
cd roles/openbao_agent
MOLECULE_DISTRO=debian13 molecule test
MOLECULE_DISTRO=debian13 molecule test -s invalid-config
```

## License

Apache License 2.0. See [LICENSE](LICENSE). The `openbao` role is derived from
[ansible-role-openbao](https://github.com/robertdebock/ansible-role-openbao)
by Robert de Bock; see [roles/openbao/NOTICE](roles/openbao/NOTICE).

---

This project is maintained by [Digitalis.io](https://digitalis.io). For support, visit [digitalis.io/contact](https://digitalis.io/contact).
