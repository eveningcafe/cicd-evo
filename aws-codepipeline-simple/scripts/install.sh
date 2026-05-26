#!/bin/bash
# Stop old gunicorn, create venv (idempotent), install deps, restart.
# No systemd unit — just nohup'd gunicorn for simplicity.
set -euo pipefail

# Kill anything currently listening on :8080.
pkill -f "gunicorn.*:8080" || true
sleep 1

PYTHON=$(command -v python3.11 || command -v python3)

if [ ! -d /opt/sample-app/venv ]; then
  "$PYTHON" -m venv /opt/sample-app/venv
fi

/opt/sample-app/venv/bin/pip install --upgrade pip
/opt/sample-app/venv/bin/pip install -r /opt/sample-app/app/requirements.txt

chown -R ec2-user:ec2-user /opt/sample-app

# Start gunicorn in background, detached from CodeDeploy's session.
sudo -u ec2-user APP_ENVIRONMENT=simple-demo APP_GREETING=hello-from-simple-demo-02 \
  nohup /opt/sample-app/venv/bin/gunicorn \
    -w 2 -b 0.0.0.0:8080 \
    --chdir /opt/sample-app/app \
    --pid /tmp/sample-app.pid \
    --daemon \
    app:app
