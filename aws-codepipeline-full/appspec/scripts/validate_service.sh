#!/bin/bash
# Poll /healthz locally for up to 60s. CodeDeploy treats a non-zero exit here
# as a failed deployment and (for Blue/Green) skips the listener swap.
set -euo pipefail

for i in $(seq 1 30); do
  if curl -fsS --max-time 2 http://127.0.0.1:8080/healthz | grep -q '"ok"'; then
    echo "Health check passed on attempt ${i}"
    exit 0
  fi
  sleep 2
done

echo "Health check failed after 60s"
systemctl status sample-app --no-pager || true
journalctl -u sample-app -n 50 --no-pager || true
exit 1
