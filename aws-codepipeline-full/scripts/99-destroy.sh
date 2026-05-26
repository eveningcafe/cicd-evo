#!/usr/bin/env bash
# Empties any non-empty S3 buckets (Terraform can't delete those by default)
# then runs terraform destroy.
set -euo pipefail

cd "$(dirname "$0")/../terraform"
REGION=$(terraform output -raw region 2>/dev/null || echo "")

empty_bucket() {
  local bucket="$1"
  if [ -z "$bucket" ] || [ "$bucket" = "null" ]; then
    return
  fi
  echo "Emptying s3://$bucket ..."
  # Delete all versions + delete markers (bucket has versioning enabled).
  aws s3api delete-objects --bucket "$bucket" --region "$REGION" \
    --delete "$(aws s3api list-object-versions --bucket "$bucket" --region "$REGION" \
      --output=json --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
      2>/dev/null | jq -c '.')" \
    2>/dev/null || true
  aws s3api delete-objects --bucket "$bucket" --region "$REGION" \
    --delete "$(aws s3api list-object-versions --bucket "$bucket" --region "$REGION" \
      --output=json --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
      2>/dev/null | jq -c '.')" \
    2>/dev/null || true
  # Fallback for non-versioned objects.
  aws s3 rm "s3://$bucket" --recursive --region "$REGION" 2>/dev/null || true
}

ARTIFACTS_BUCKET=$(terraform output -raw artifacts_bucket 2>/dev/null || echo "")

empty_bucket "$ARTIFACTS_BUCKET"

terraform destroy -auto-approve
echo "Demo torn down."
