#!/usr/bin/env bash
# terraform init + apply for the demo.
set -euo pipefail

cd "$(dirname "$0")/../terraform"

if [ ! -f terraform.tfvars ]; then
  echo "[ERROR] terraform.tfvars not found. Copy terraform.tfvars.example first."
  exit 1
fi

terraform init -upgrade
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
rm -f tfplan

echo
echo "=== Useful outputs ==="
terraform output
