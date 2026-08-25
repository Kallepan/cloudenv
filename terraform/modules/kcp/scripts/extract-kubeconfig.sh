#!/usr/bin/env bash
# Extracts kcp's runtime-generated admin.kubeconfig and rewrites its cluster
# server URLs to the HAProxy passthrough hostname so TLS verification succeeds
# (kcp's own kubeconfig points at its internal Docker IP, which the mkcert
# cert has no SAN for).
set -euo pipefail

: "${KCP_CONTAINER:?KCP_CONTAINER env var required}"
: "${KCP_SRC:?KCP_SRC env var required}"
: "${KCP_DST:?KCP_DST env var required}"
: "${KCP_HOSTNAME:?KCP_HOSTNAME env var required}"
: "${KCP_PORT:?KCP_PORT env var required}"

tmp="${KCP_DST}.tmp"

mkdir -p "$(dirname "${KCP_DST}")"

# Wait for kcp to generate the admin kubeconfig inside the container.
max_attempts=60
attempt=1
until docker exec "${KCP_CONTAINER}" sh -lc "test -f '${KCP_SRC}'" >/dev/null 2>&1; do
  if [ "${attempt}" -ge "${max_attempts}" ]; then
    echo "Timed out waiting for ${KCP_SRC} in container ${KCP_CONTAINER}" >&2
    docker logs "${KCP_CONTAINER}" 2>&1 | tail -n 80 >&2 || true
    exit 1
  fi
  attempt=$((attempt + 1))
  sleep 2
done

docker cp "${KCP_CONTAINER}:${KCP_SRC}" "${tmp}"

KUBECONFIG="${tmp}" kubectl config set-cluster root --server="https://${KCP_HOSTNAME}:${KCP_PORT}/clusters/root" >/dev/null || true
KUBECONFIG="${tmp}" kubectl config set-cluster base --server="https://${KCP_HOSTNAME}:${KCP_PORT}" >/dev/null || true
KUBECONFIG="${tmp}" kubectl config set-cluster system:admin --server="https://${KCP_HOSTNAME}:${KCP_PORT}/clusters/system:admin" >/dev/null || true

mv "${tmp}" "${KCP_DST}"
chmod 0644 "${KCP_DST}"
