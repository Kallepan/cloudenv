kubeconfig := justfile_directory() + "/.configs/kubeconfig"
talosconfig := justfile_directory() + "/.configs/talosconfig"

export KUBECONFIG := kubeconfig
export TALOSCONFIG := talosconfig

# List available recipes
default:
    @just --list

# Create the cluster
up:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{justfile_directory()}}/terraform"
    tofu init -input=false
    tofu apply -var-file="local-talos.tfvars" -auto-approve

# Destroy the cluster
down:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{justfile_directory()}}/terraform"
    tofu destroy -var-file="local-talos.tfvars" -auto-approve

# Destroy then recreate
reset:
    just down
    just up

# Show cluster info
status:
    kubectl cluster-info

# Open k9s dashboard
k9s:
    k9s

# Apply base kustomize manifests
deploy-base:
    kubectl apply -k manifests/base

# Apply dev overlay
deploy-dev:
    kubectl apply -k manifests/overlays/dev

# Apply staging overlay
deploy-staging:
    kubectl apply -k manifests/overlays/staging

# Install Flux (no git bootstrap)
flux-install:
    flux install --namespace=flux-system

# Bootstrap Flux with a git repo
flux-bootstrap url branch="main" path="manifests/base":
    flux bootstrap git \
        --url={{url}} \
        --branch={{branch}} \
        --path={{path}}

# Configure macOS DNS resolver so *.home.lab resolves via the dnsmasq container
setup-dns domain="home.lab" nameserver="10.5.0.3":
    #!/usr/bin/env bash
    set -euo pipefail
    sudo mkdir -p /etc/resolver
    printf "domain %s\nsearch %s\nnameserver %s\n" \
        "{{domain}}" "{{domain}}" "{{nameserver}}" \
        | sudo tee /etc/resolver/{{domain}} > /dev/null
    echo "DNS resolver configured: *.{{domain}} -> {{nameserver}}"

