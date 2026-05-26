#!/usr/bin/env bash
# Curl the staging instance (by tag) and prod ALB to confirm the app is alive.
set -euo pipefail

cd "$(dirname "$0")/../terraform"
REGION=$(terraform output -raw region)
PROJECT=$(terraform output -raw pipeline_name)
ALB_DNS=$(terraform output -raw prod_alb_dns)

echo "=== Staging ==="
STAGING_IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:Project,Values=$PROJECT" \
            "Name=tag:Environment,Values=staging" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[0].PublicIpAddress" \
  --output text)

if [ -z "$STAGING_IP" ] || [ "$STAGING_IP" = "None" ]; then
  echo "No running staging instance found."
else
  echo "  Public IP: $STAGING_IP"
  echo "  /healthz   -> $(curl -fsS --max-time 5 http://${STAGING_IP}:8080/healthz || echo FAILED)"
  echo "  /readyz    -> $(curl -fsS --max-time 5 http://${STAGING_IP}:8080/readyz  || echo FAILED)"
  echo "  /          -> $(curl -fsS --max-time 5 http://${STAGING_IP}:8080/        || echo FAILED)"
fi

echo
echo "=== Production (ALB) ==="
echo "  ALB DNS: $ALB_DNS"
echo "  /healthz   -> $(curl -fsS --max-time 5 http://${ALB_DNS}/healthz || echo FAILED)"
echo "  /readyz    -> $(curl -fsS --max-time 5 http://${ALB_DNS}/readyz  || echo FAILED)"
echo "  /          -> $(curl -fsS --max-time 5 http://${ALB_DNS}/        || echo FAILED)"
