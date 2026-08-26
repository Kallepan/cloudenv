#!/usr/bin/env bash
# Pushes local manifests to the in-cluster OCI registry, optionally trusts a
# custom CA for it, then applies the OCIRepository + Kustomization pair that
# tells Flux to reconcile from that pushed artifact.
set -euo pipefail

: "${FLUX_MANIFESTS_PATH:?FLUX_MANIFESTS_PATH env var required}"
: "${FLUX_REGISTRY_DOMAIN:?FLUX_REGISTRY_DOMAIN env var required}"
: "${FLUX_OCI_REPO_NAME:?FLUX_OCI_REPO_NAME env var required}"
: "${FLUX_OCI_TAG:?FLUX_OCI_TAG env var required}"
: "${FLUX_REVISION:?FLUX_REVISION env var required}"
: "${FLUX_SYNC_MANIFEST:?FLUX_SYNC_MANIFEST env var required}"

flux push artifact "oci://${FLUX_REGISTRY_DOMAIN}/${FLUX_OCI_REPO_NAME}:${FLUX_OCI_TAG}" \
  --path="${FLUX_MANIFESTS_PATH}" \
  --source="local://terraform" \
  --revision="terraform@sha1:${FLUX_REVISION}"

if [ -n "${FLUX_CA_FILE:-}" ]; then
  kubectl -n flux-system create secret generic "${FLUX_OCI_REPO_NAME}-ca" \
    --from-file=ca.crt="${FLUX_CA_FILE}" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

kubectl apply -f "${FLUX_SYNC_MANIFEST}"
