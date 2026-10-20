#!/usr/bin/env python3
"""Check that each role's meta/argument_specs.yml is complete.

For every role under the given roots (default: roles/) the check requires:

* every public variable in defaults/ and vars/ (no leading underscore) has
  an entry in the spec;
* every entry has a type and a description, and either a default or
  required: true, unless it is optional and unset (not in defaults/);
* a default in the spec equals the value in defaults/main.yml.

Exit status is 1 when a gap is found, unless --report-only is given.
"""
import argparse
import sys
from pathlib import Path

import yaml


def load_yaml_dir(path):
    values = {}
    for f in sorted(path.rglob("*.y*ml")):
        data = yaml.safe_load(f.read_text()) or {}
        if isinstance(data, dict):
            values.update(data)
    return values


def check_role(role):
    problems = []
    spec_file = role / "meta" / "argument_specs.yml"
    if not spec_file.exists():
        return [f"{role.name}: meta/argument_specs.yml is missing"]

    spec = yaml.safe_load(spec_file.read_text()) or {}
    options = ((spec.get("argument_specs") or {}).get("main") or {}).get("options") or {}
    defaults = load_yaml_dir(role / "defaults")
    constants = load_yaml_dir(role / "vars")

    for source, values in (("defaults", defaults), ("vars", constants)):
        for name in values:
            if not name.startswith("_") and name not in options:
                problems.append(
                    f"{role.name}: {name} is in {source}/ but not in the spec "
                    "(document it, or prefix it with _ if it is internal)"
                )

    for name, option in options.items():
        if "type" not in option:
            problems.append(f"{role.name}: {name} has no type")
        if not option.get("description"):
            problems.append(f"{role.name}: {name} has no description")
        if "default" not in option and not option.get("required") and name in defaults:
            problems.append(f"{role.name}: {name} is in defaults/ but has neither a default nor required: true in the spec")
        if "default" in option and name in defaults and option["default"] != defaults[name]:
            problems.append(
                f"{role.name}: {name} default in the spec ({option['default']!r}) "
                f"differs from defaults/ ({defaults[name]!r})"
            )
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("roots", nargs="*", default=["roles"], help="directories that contain roles")
    parser.add_argument("--report-only", action="store_true", help="print gaps but exit 0")
    args = parser.parse_args()

    problems = []
    for root in args.roots:
        for role in sorted(p for p in Path(root).iterdir() if p.is_dir()):
            problems += check_role(role)

    for problem in problems:
        print(problem)
    if problems:
        print(f"{len(problems)} gap(s) found")
        return 0 if args.report_only else 1
    print("argument_specs are complete")
    return 0


if __name__ == "__main__":
    sys.exit(main())
