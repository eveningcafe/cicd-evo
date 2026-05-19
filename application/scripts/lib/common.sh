#!/usr/bin/env bash
# Shared helpers for the thick scripts. Sourced by build/test/deploy.
# Keeping the helpers in one place is exactly the "shared scripts library"
# mentioned in Phần VII (Platform team responsibilities).

set -euo pipefail

# Resolve paths relative to the application/ directory regardless of CWD.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${APP_DIR}/.." && pwd)"

# Default values. Override via environment for local runs.
: "${IMAGE_REGISTRY:=ghcr.io/example-org}"
: "${IMAGE_NAME:=sample-app}"
: "${MANIFEST_REPO:=${REPO_ROOT}/manifests}"

log() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

die() {
  log "ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command '$1' not found in PATH"
}

# Single source of truth for the version tag. Used everywhere from build to
# deploy so the "Build Once, Deploy Anywhere" guarantee holds.
resolve_version() {
  if [[ -n "${APP_VERSION:-}" ]]; then
    printf '%s' "${APP_VERSION}"
    return
  fi
  if command -v git >/dev/null 2>&1 && git -C "${REPO_ROOT}" rev-parse --short HEAD >/dev/null 2>&1; then
    git -C "${REPO_ROOT}" rev-parse --short HEAD
  else
    printf 'local-%s' "$(date +%s)"
  fi
}

image_ref() {
  local version="$1"
  printf '%s/%s:%s' "${IMAGE_REGISTRY}" "${IMAGE_NAME}" "${version}"
}

validate_environment() {
  local env="$1"
  case "${env}" in
    dev|staging|prod) ;;
    *) die "unknown environment '${env}'. Use one of: dev, staging, prod" ;;
  esac
}
