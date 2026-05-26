#!/bin/bash
# Bootstrap script for every EC2 instance launched by the demo.
# Installs Python toolchain + CodeDeploy agent.
set -euo pipefail

dnf install -y python3.11 python3.11-pip ruby wget

# CodeDeploy agent: bucket name is region-specific.
REGION="${region}"
cd /tmp
wget -q "https://aws-codedeploy-$${REGION}.s3.$${REGION}.amazonaws.com/latest/install"
chmod +x ./install
./install auto

systemctl enable codedeploy-agent
systemctl start codedeploy-agent

# Per-host env file consumed by sample-app.service (EnvironmentFile).
cat >/etc/sample-app.env <<EOF
APP_ENVIRONMENT=${environment}
APP_VERSION=bootstrap
APP_GREETING=hello-from-${environment}
EOF
