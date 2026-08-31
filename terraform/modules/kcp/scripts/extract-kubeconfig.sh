#!/usr/bin/env bash
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
until docker exec "${KCP_CONTAINER}" test -f "${KCP_SRC}" >/dev/null 2>&1; do
  if [ "${attempt}" -ge "${max_attempts}" ]; then
    echo "Timed out waiting for ${KCP_SRC} in container ${KCP_CONTAINER}" >&2
    docker logs "${KCP_CONTAINER}" 2>&1 | tail -n 80 >&2 || true
    exit 1
  fi
  attempt=$((attempt + 1))
  sleep 2
done

docker cp "${KCP_CONTAINER}:${KCP_SRC}" "${tmp}"

# Update all existing clusters in the kubeconfig dynamically to point to the new host:port
clusters=$(KUBECONFIG="${tmp}" kubectl config get-clusters | tail -n +2)
for cluster in ${clusters}; do
  if [ "${cluster}" = "base" ]; then
    KUBECONFIG="${tmp}" kubectl config set-cluster "${cluster}" --server="https://${KCP_HOSTNAME}:${KCP_PORT}" >/dev/null
  else
    KUBECONFIG="${tmp}" kubectl config set-cluster "${cluster}" --server="https://${KCP_HOSTNAME}:${KCP_PORT}/clusters/${cluster}" >/dev/null
  fi
done

mv "${tmp}" "${KCP_DST}"
chmod 0600 "${KCP_DST}"
