#!/bin/bash
# Stop any old instance & clean install dir before files are copied in.
set -euo pipefail

if systemctl is-active --quiet sample-app; then
  systemctl stop sample-app || true
fi

# Wipe previous install but keep the venv to speed up redeploys.
rm -rf /opt/sample-app/app
mkdir -p /opt/sample-app/app
chown -R ec2-user:ec2-user /opt/sample-app
