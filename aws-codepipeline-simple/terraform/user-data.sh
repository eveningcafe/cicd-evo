#!/bin/bash
set -euo pipefail
dnf install -y python3.11 python3.11-pip ruby wget

REGION="${region}"
cd /tmp
wget -q "https://aws-codedeploy-$${REGION}.s3.$${REGION}.amazonaws.com/latest/install"
chmod +x ./install
./install auto

systemctl enable codedeploy-agent
systemctl start codedeploy-agent
