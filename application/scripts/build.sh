#!/usr/bin/env bash
# Build the application image. Runs identically on a developer laptop and on
# any CI provider — that is the whole point of the Thin CI pattern.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

require_cmd docker

VERSION="$(resolve_version)"
IMAGE="$(image_ref "${VERSION}")"

log "Building ${IMAGE}"
docker build \
  --build-arg "APP_VERSION=${VERSION}" \
  --tag "${IMAGE}" \
  --tag "${IMAGE_REGISTRY}/${IMAGE_NAME}:latest" \
  "${APP_DIR}"

log "Built ${IMAGE}"

# Emit metadata that downstream steps (test, deploy) can consume without
# having to recompute the version. Useful in CI where each stage starts fresh.
mkdir -p "${APP_DIR}/.build"
printf '%s\n' "${VERSION}" > "${APP_DIR}/.build/version"
printf '%s\n' "${IMAGE}" > "${APP_DIR}/.build/image"
