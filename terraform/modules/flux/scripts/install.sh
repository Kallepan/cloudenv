#!/usr/bin/env bash
# Installs Flux, bootstrapping against a git repo when FLUX_GIT_URL is set,
# otherwise a plain in-cluster install with no git source.
set -euo pipefail

if [ -n "${FLUX_GIT_URL:-}" ]; then
  flux bootstrap git \
    --url="${FLUX_GIT_URL}" \
    --branch="${FLUX_GIT_BRANCH:-main}" \
    --path="${FLUX_GIT_PATH:-manifests/base}"
else
  flux install --namespace=flux-system
fi
