<p align="center">
  <a href="https://digitalis.io">
    <img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/DigitalisDigital_DigitalisFullLogoGradient+-+medium.png" alt="Digitalis.io" width="300">
  </a>
</p>

# openbao

Install the OpenBao server package from the upstream repository on Red Hat Enterprise Linux, Debian and Ubuntu.

## Quick start

```yaml
- name: Install OpenBao
  hosts: openbao
  become: true
  roles:
    - role: digitalis.digitalis.openbao
```

The package creates the `openbao` user, `/etc/openbao/openbao.hcl` and the
`openbao` systemd unit. The service is left as the package created it unless
`openbao_service_manage` is true.

## Examples

Pin a version and start the server with the packaged configuration:

```yaml
- role: digitalis.digitalis.openbao
  vars:
    openbao_version: "2.7.1"
    openbao_service_manage: true
```

Install from an internal mirror that is already configured on the host:

```yaml
- role: digitalis.digitalis.openbao
  vars:
    openbao_manage_repository: false
```

## Variables

| Variable | Type | Default | Example |
|----------|------|---------|---------|
| `openbao_version` | str | `2.7.1` | `2.6.4` |
| `openbao_manage_repository` | bool | `true` | `false` |
| `openbao_gpg_key_url` | str | `https://openbao.org/assets/openbao-gpg-pub-20240618.asc` | mirror URL |
| `openbao_validate_certs` | bool | `true` | `false` |
| `openbao_apt_repository_uri` | str | `https://pkgs.openbao.org/deb` | mirror URL |
| `openbao_apt_repository_suite` | str | `stable` | `stable` |
| `openbao_apt_repository_components` | str | `main` | `main` |
| `openbao_yum_repository_baseurl` | str | `https://pkgs.openbao.org/rpm/$basearch` | mirror URL |
| `openbao_service_manage` | bool | `false` | `true` |
| `openbao_service_enabled` | bool | `true` | `false` |
| `openbao_service_state` | str | `started` | `stopped` |

`openbao_version` must be a full package version such as `2.7.1`; anything
else fails before the host is changed.

## Supported platforms

Red Hat Enterprise Linux 9 and 10 (and rebuilds), Debian 12 and 13, Ubuntu 22.04 and 24.04.

## Testing

```bash
MOLECULE_DISTRO=rockylinux9 molecule test
MOLECULE_DISTRO=rockylinux9 molecule test -s invalid-version
```

## License

Apache License 2.0. Derived from
[ansible-role-openbao](https://github.com/robertdebock/ansible-role-openbao) by
Robert de Bock; see [NOTICE](NOTICE).

---

Maintained by [Digitalis.io](https://digitalis.io). Support at [digitalis.io/contact](https://digitalis.io/contact).
