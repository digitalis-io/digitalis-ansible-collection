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

## Quick start

1. Install the collection from Ansible Galaxy (after the first release is published), or straight from GitHub:

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

2. Fetch AppRole credentials for the host from your OpenBao server:

   ```bash
   bao read -field=role_id auth/approle/role/myapp/role-id
   bao write -f -field=secret_id auth/approle/role/myapp/secret-id
   ```

3. Store them encrypted with ansible-vault:

   ```bash
   ansible-vault create group_vars/app_servers/vault.yml
   ```

   ```yaml
   vault_openbao_role_id: "<role_id>"
   vault_openbao_secret_id: "<secret_id>"
   ```

4. Write `site.yml`:

   ```yaml
   - name: Render application secrets with OpenBao Agent
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
               contents: !unsafe |
                 {{ with secret "secret/data/myapp" }}DB_PASSWORD={{ .Data.data.password }}{{ end }}
   ```

5. Run it:

   ```bash
   ansible-playbook -i inventory site.yml --ask-vault-pass
   ```

The role installs OpenBao, starts the `openbao-agent` service and writes
`/etc/myapp/db.env` with mode `0600`. The agent keeps the file up to date when
the secret changes; Ansible does not need to run again.

Inline templates must be tagged `!unsafe` so Ansible leaves the `{{ }}`
markers for the agent.

## Examples

Install the OpenBao server and start it with the packaged configuration
(pebbledb storage, self-signed TLS on port 8200):

```yaml
- name: Install OpenBao server
  hosts: openbao
  become: true
  roles:
    - role: digitalis.digitalis.openbao
      vars:
        openbao_version: "2.7.1"
        openbao_service_manage: true
```

Render a certificate from a template file kept next to the playbook, readable
by the `nginx` group, and reload nginx when it changes:

```yaml
- role: digitalis.digitalis.openbao_agent
  vars:
    openbao_agent_address: https://openbao.example.com:8200
    openbao_agent_approle_role_id: "{{ vault_openbao_role_id }}"
    openbao_agent_approle_secret_id: "{{ vault_openbao_secret_id }}"
    openbao_agent_group: nginx
    openbao_agent_templates:
      - destination: /etc/nginx/tls/server.pem
        src: files/server.pem.ctmpl
        perms: "0640"
        exec_command: ["systemctl", "reload", "nginx"]
```

The agent runs without privileges, so the reload needs a polkit rule allowing
the agent user to reload `nginx.service`. See the
[openbao_agent README](roles/openbao_agent/README.md) for every option.

## Roles

| Role | Description |
|------|-------------|
| [openbao](roles/openbao/README.md) | Install the OpenBao server package from the upstream repository |
| [openbao_agent](roles/openbao_agent/README.md) | Install and run OpenBao Agent to render secrets to files |
| [rabbitmq](roles/rabbitmq/README.md) | Install and configure RabbitMQ, including clustering, TLS and queues |

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
