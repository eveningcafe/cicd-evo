#!/usr/bin/env bash
# Polls pipeline state every 10s. Prints stage transitions as they happen.
# Exits when the pipeline reaches a terminal state OR hits the manual
# approval action (so user can run 04-approve-prod.sh).
set -euo pipefail

cd "$(dirname "$0")/../terraform"
PIPELINE=$(terraform output -raw pipeline_name)
REGION=$(terraform output -raw region)

echo "Watching pipeline: $PIPELINE  (region: $REGION)"
echo "Ctrl-C to stop. Re-run any time."
echo

prev_state=""

while true; do
  STATE_JSON=$(aws codepipeline get-pipeline-state --name "$PIPELINE" --region "$REGION")

  # One-line summary per stage
  SUMMARY=$(echo "$STATE_JSON" | jq -r '
    .stageStates[] |
    "  " + (.stageName | ascii_upcase) + ": " +
    ((.latestExecution.status // "Idle"))
  ')

  if [ "$SUMMARY" != "$prev_state" ]; then
    date +"[%H:%M:%S]"
    echo "$SUMMARY"
    prev_state="$SUMMARY"
  fi

  # Check for waiting manual approval
  PENDING_APPROVAL=$(echo "$STATE_JSON" | jq -r '
    .stageStates[]
    | select(.stageName == "Production")
    | .actionStates[]
    | select(.actionName == "ApproveProd")
    | .latestExecution.status // "None"
  ')
  if [ "$PENDING_APPROVAL" = "InProgress" ]; then
    echo
    echo ">>> Pipeline is waiting for production approval."
    echo ">>> Run ./scripts/04-approve-prod.sh to release it."
    echo
  fi

  # Terminal state of last stage
  LAST_STATUS=$(echo "$STATE_JSON" | jq -r '.stageStates[-1].latestExecution.status // "None"')
  if [ "$LAST_STATUS" = "Succeeded" ]; then
    echo ">>> Pipeline succeeded end-to-end."
    exit 0
  fi
  if [ "$LAST_STATUS" = "Failed" ]; then
    echo ">>> Pipeline failed in the last stage. Inspect in the AWS Console."
    exit 1
  fi

  sleep 10
done
