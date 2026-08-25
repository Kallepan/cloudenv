#!/usr/bin/env bash
# Called by data "external" — reads JSON query from stdin, writes JSON to stdout
set -euo pipefail

query=$(cat)
domain=$(echo "$query" | jq -r '.domain')
output_dir=$(echo "$query" | jq -r '.output_dir')

mkdir -p "$output_dir"

# Add root CA to system trust store (no-op if already trusted)
mkcert -install 2>/dev/null || true

cert_file="$output_dir/tls.crt"
key_file="$output_dir/tls.key"

if [[ ! -f "$cert_file" || ! -f "$key_file" ]]; then
  mkcert \
    -cert-file "$cert_file" \
    -key-file  "$key_file" \
    "*.$domain" "$domain"
fi

ca_root=$(mkcert -CAROOT)

jq -n \
  --rawfile cert    "$cert_file" \
  --rawfile key     "$key_file" \
  --rawfile root_ca "$ca_root/rootCA.pem" \
  '{cert: $cert, key: $key, root_ca: $root_ca}'
