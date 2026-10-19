#!/usr/bin/env bash
# Regenerate the variable tables between the BEGIN_ANSIBLE_DOCS and
# END_ANSIBLE_DOCS markers of every role README from meta/argument_specs.yml.
# Requires aar-doc (pip install -r scripts/requirements-docs.txt).
set -euo pipefail

cd "$(dirname "$0")/.."

for role in roles/*/; do
  aar-doc \
    --output-mode inject \
    --output-template scripts/aar-doc-template.j2 \
    "${role%/}" markdown
done
