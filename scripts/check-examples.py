#!/usr/bin/env python3
"""Check every playbook under examples/.

Each playbook must pass `ansible-playbook --syntax-check`, and every role
variable it sets must be documented in the role's meta/argument_specs.yml and
pass the type validation defined there. The collection must be installed
(ansible-galaxy collection install .) so the roles resolve.
"""
import pathlib
import subprocess
import sys

import yaml
from ansible.module_utils.common.arg_spec import ArgumentSpecValidator
from ansible.parsing.dataloader import DataLoader

ROOT = pathlib.Path(__file__).resolve().parent.parent
PREFIX = "digitalis.digitalis."


def role_spec(role):
    path = ROOT / "roles" / role / "meta" / "argument_specs.yml"
    return yaml.safe_load(path.read_text())["argument_specs"]["main"]["options"]


def check_vars(playbook, role, role_vars):
    errors = []
    spec = role_spec(role)
    for name in role_vars:
        if name.startswith(role + "_") and name not in spec:
            errors.append(f"{playbook}: {role}: undocumented variable {name}")
    # Templated values are only known at run time. A string option gets a
    # placeholder so that required options set from a lookup count as given;
    # other types are skipped.
    values = {}
    for k, v in role_vars.items():
        if k not in spec:
            continue
        if isinstance(v, str) and "{{" in v:
            if spec[k].get("type", "str") == "str":
                values[k] = "placeholder"
            continue
        values[k] = v
    result = ArgumentSpecValidator(spec).validate(values)
    errors.extend(f"{playbook}: {role}: {m}" for m in result.error_messages)
    return errors


def main():
    errors = []
    loader = DataLoader()
    for playbook in sorted((ROOT / "examples").glob("*/playbook.yml")):
        rel = playbook.relative_to(ROOT)
        proc = subprocess.run(
            [
                "ansible-playbook",
                "--syntax-check",
                "-i",
                str(playbook.with_name("inventory.yml")),
                str(playbook),
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        if proc.returncode != 0:
            errors.append(f"{rel}: syntax check failed\n{proc.stdout}{proc.stderr}")
        for play in loader.load_from_file(str(playbook)):
            for entry in play.get("roles", []):
                if not isinstance(entry, dict):
                    continue
                name = entry.get("role", "")
                if name.startswith(PREFIX):
                    errors.extend(
                        check_vars(rel, name[len(PREFIX):], entry.get("vars", {}))
                    )
    for error in errors:
        print(error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
