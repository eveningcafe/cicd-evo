#!/bin/bash
# Install Python dependencies into a venv & reload systemd unit.
set -euo pipefail

PYTHON=$(command -v python3.11 || command -v python3)

if [ ! -d /opt/sample-app/venv ]; then
  "$PYTHON" -m venv /opt/sample-app/venv
fi

/opt/sample-app/venv/bin/pip install --upgrade pip
/opt/sample-app/venv/bin/pip install -r /opt/sample-app/app/requirements.txt

# Pick up env vars per-host (set via user-data).
if [ -f /etc/sample-app.env ]; then
  cp /etc/sample-app.env /opt/sample-app/app.env
fi

chown -R ec2-user:ec2-user /opt/sample-app

systemctl daemon-reload
systemctl enable sample-app
