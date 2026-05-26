#!/bin/bash
# Idempotent: succeeds even if the service has never been installed.
set -euo pipefail

if systemctl list-unit-files | grep -q '^sample-app\.service'; then
  systemctl stop sample-app || true
fi
