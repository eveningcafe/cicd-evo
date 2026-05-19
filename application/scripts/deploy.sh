#!/usr/bin/env bash
# Deploy by committing the new image tag into the manifest repository.
#
# This is the "CI tự commit" pattern from Phần IV §4.3: CI builds the image,
# then writes the new tag into Git. Argo CD picks up the change on its next
# sync. Git stays the single source of truth.
#
# In a real setup the manifest repo would be a separate Git repo and this
# script would `git clone`/`git push` against it. For the demo we operate
# directly on the in-tree `manifests/` directory.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

require_cmd sed

ENVIRONMENT="${1:-}"
[[ -n "${ENVIRONMENT}" ]] || die "usage: $0 <dev|staging|prod>"
validate_environment "${ENVIRONMENT}"

VERSION="$(cat "${APP_DIR}/.build/version" 2>/dev/null || resolve_version)"
IMAGE="$(image_ref "${VERSION}")"

OVERLAY_DIR="${MANIFEST_REPO}/apps/sample-app/overlays/${ENVIRONMENT}"
KUSTOMIZATION="${OVERLAY_DIR}/kustomization.yaml"

[[ -f "${KUSTOMIZATION}" ]] || die "kustomization not found: ${KUSTOMIZATION}"

log "Pinning ${ENVIRONMENT} overlay to ${IMAGE}"
if command -v kustomize >/dev/null 2>&1; then
  (cd "${OVERLAY_DIR}" && kustomize edit set image "${IMAGE_REGISTRY}/${IMAGE_NAME}:${VERSION}")
else
  # Fallback for hosts without kustomize. Works because each overlay has
  # exactly one `newTag:` line — the one we want to rewrite.
  sed -i.bak "s|^\(\s*newTag:\) .*|\1 ${VERSION}|" "${KUSTOMIZATION}"
  rm -f "${KUSTOMIZATION}.bak"
fi

log "Updated ${KUSTOMIZATION}"

# In a real deployment this is where you'd commit and push to the manifest
# repo. Argo CD's sync loop would then roll out the new tag automatically.
if command -v git >/dev/null 2>&1 && git -C "${MANIFEST_REPO}" rev-parse >/dev/null 2>&1; then
  git -C "${MANIFEST_REPO}" add "apps/sample-app/overlays/${ENVIRONMENT}/kustomization.yaml"
  git -C "${MANIFEST_REPO}" commit -m "deploy(${ENVIRONMENT}): ${IMAGE_NAME} ${VERSION}" || log "no changes to commit"
  log "Committed. Push to trigger Argo CD sync."
else
  log "Manifest dir is not a git repo — skipping commit. Update applied in place."
fi
