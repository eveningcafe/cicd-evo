#!/usr/bin/env bash
# Run the unit tests. Identical on laptop and CI.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

require_cmd python3

cd "${APP_DIR}"

log "Installing test dependencies"
python3 -m pip install --quiet --disable-pip-version-check -r src/requirements.txt pytest

log "Running pytest"
PYTHONPATH="${APP_DIR}/src" python3 -m pytest tests/ -v
