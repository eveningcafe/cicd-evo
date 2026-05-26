#!/usr/bin/env bash
# Pushes the local repo to the CodeCommit source. EventBridge will start
# the pipeline within ~10s of the push completing.
set -euo pipefail

cd "$(dirname "$0")/../terraform"

GRC_URL=$(terraform output -raw codecommit_clone_url_grc)
REPO_ROOT="$(cd ../.. && pwd)"

echo "Pushing $REPO_ROOT to $GRC_URL ..."
(
  cd "$REPO_ROOT"
  if git remote get-url aws >/dev/null 2>&1; then
    git remote set-url aws "$GRC_URL"
  else
    git remote add aws "$GRC_URL"
  fi
  git push aws HEAD:main
)

echo "Push complete. EventBridge will start the pipeline within ~10s."
