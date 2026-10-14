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

## Quick start

```bash
ansible-galaxy collection install git+https://github.com/digitalis-io/digitalis-ansible-collection.git
```

```yaml
- name: Install OpenBao Agent
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

## Roles

| Role | Description |
|------|-------------|
| [openbao](roles/openbao/README.md) | Install the OpenBao server package from the upstream repository |
| [openbao_agent](roles/openbao_agent/README.md) | Install and run OpenBao Agent to render secrets to files |

## Supported platforms

| Distribution | Versions |
|--------------|----------|
| Red Hat Enterprise Linux and rebuilds (Rocky, Alma) | 9, 10 |
| Debian | 12 (bookworm), 13 (trixie) |
| Ubuntu | 22.04 (jammy), 24.04 (noble) |

## Testing

Each role has Molecule scenarios under `roles/<role>/molecule/`, driven by
`MOLECULE_DISTRO` (`rockylinux9`, `rockylinux10`, `ubuntu2204`, `ubuntu2404`,
`debian12`, `debian13`):

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

Maintained by [Digitalis.io](https://digitalis.io). Support at [digitalis.io/contact](https://digitalis.io/contact).
