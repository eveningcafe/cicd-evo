#!/bin/bash
# Poll /healthz for up to 60s. Non-zero exit here = CodeDeploy fails the deploy.
set -euo pipefail

for i in $(seq 1 30); do
  if curl -fsS --max-time 2 http://127.0.0.1:8080/healthz | grep -q '"ok"'; then
    echo "OK after ${i} tries"
    exit 0
  fi
  sleep 2
done

echo "validate timed out"
ps auxf | grep -i gunicorn || true
exit 1
