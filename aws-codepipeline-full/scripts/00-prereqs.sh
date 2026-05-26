#!/usr/bin/env bash
# Sanity-check tooling + AWS credentials before running terraform apply.
set -euo pipefail

cd "$(dirname "$0")/.."

fail=0
need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[MISSING] $1 — $2"
    fail=1
  else
    echo "[OK]      $1 — $(command -v "$1")"
  fi
}

need aws                   "install AWS CLI v2: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
need terraform             "install Terraform >= 1.5: https://developer.hashicorp.com/terraform/downloads"
need jq                    "install jq"
need curl                  "install curl"
need git                   "install git"
need git-remote-codecommit "pip install git-remote-codecommit"

echo
echo "=== AWS identity ==="
if ! aws sts get-caller-identity --output table; then
  echo "[ERROR] aws sts get-caller-identity failed. Configure credentials (aws configure / SSO)."
  fail=1
fi

echo
if [ "$fail" -ne 0 ]; then
  echo "Some prerequisites are missing. Fix the issues above and re-run."
  exit 1
fi
echo "All prerequisites satisfied."
