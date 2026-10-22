# CLAUDE.md

Ansible collection `digitalis.digitalis`: roles `openbao`, `openbao_agent`, `postgres_cluster`, `prometheus` and `rabbitmq`. Public repo under `digitalis-io`. Digitalis.io branding.

## Layout

- `roles/<role>/` with `defaults/`, `vars/`, `tasks/`, `meta/argument_specs.yml`, `molecule/<scenario>/` and a `README.md`.
- `examples/` complete playbooks, checked in CI by `scripts/check-examples.py`.
- `scripts/` documentation generator and the checks CI runs.
- `tests/spec-check/` fixtures for the argument_specs check.

## Conventions

- `meta/argument_specs.yml` is the source of truth for role variables. Every public variable in `defaults/` and `vars/` needs an entry with a `type`, a `description` and a `default` (or `required: true`).
- A spec `default` must equal the value in `defaults/main.yml`. Spec defaults are documentation only; Ansible does not apply them.
- Internal constants and derived values start with `_` and stay out of the spec. Renaming a public variable is breaking: note it in `CHANGELOG.md`.
- Descriptions state when to use the variable, units, interactions with other variables and side effects (restart, re-render, re-init).
- Use FQCN modules, `ansible.builtin.*`. Secrets come from vault or environment lookups, never from literals.

## Commands

```bash
scripts/generate-docs.sh                # regenerate the README variable tables
scripts/check-specs.py                  # spec completeness
tests/spec-check/run.sh                 # tests for the spec check
scripts/check-examples.py               # syntax-check examples, validate vars against specs
yamllint . && ansible-lint
cd roles/<role> && molecule test -s default
cd roles/<role> && molecule test -s invalid-config   # where the scenario exists
```

`scripts/requirements-docs.txt` pins `aar-doc`; the checks need `ansible-core` installed. On macOS use `gsed`.

## Don'ts

- Do not edit the tables between `<!-- BEGIN_ANSIBLE_DOCS -->` and `<!-- END_ANSIBLE_DOCS -->`; change the spec and regenerate. CI fails when a README is stale.
- Do not add a variable without a spec entry; CI fails on undocumented variables.
- Do not put secrets, tokens or real hostnames in examples, READMEs or tests.
- Do not set a spec `default` that differs from `defaults/main.yml`.
- Do not commit with `--no-verify` or unsigned; commits are signed and signed-off with the `@digitalis.io` identity.
- Do not change a molecule scenario without keeping its `.feature` file in step.
