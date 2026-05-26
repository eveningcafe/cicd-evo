#!/usr/bin/env bash
# Releases the Production stage manual approval.
set -euo pipefail

cd "$(dirname "$0")/../terraform"
PIPELINE=$(terraform output -raw pipeline_name)
REGION=$(terraform output -raw region)

# Find the in-progress approval token.
TOKEN=$(aws codepipeline get-pipeline-state \
  --name "$PIPELINE" \
  --region "$REGION" \
  --query "stageStates[?stageName=='Production'].actionStates[?actionName=='ApproveProd'].latestExecution.token | [0][0]" \
  --output text)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "None" ]; then
  echo "No pending approval found. Is the pipeline at the Production stage?"
  exit 1
fi

echo "Approving Production stage (token: ${TOKEN:0:8}...)"

aws codepipeline put-approval-result \
  --pipeline-name "$PIPELINE" \
  --stage-name Production \
  --action-name ApproveProd \
  --token "$TOKEN" \
  --result "summary=Approved by 04-approve-prod.sh,status=Approved" \
  --region "$REGION"

echo "Approved. CodeDeploy Blue/Green will start."
