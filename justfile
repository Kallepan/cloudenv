kubeconfig := justfile_directory() + "/.configs/kubeconfig"
talosconfig := justfile_directory() + "/.configs/talosconfig"
kcp_kubeconfig := justfile_directory() + "/.configs/kcp-kubeconfig"

export KUBECONFIG := kubeconfig
export TALOSCONFIG := talosconfig
export KUBECONFIG_KCP := kcp_kubeconfig

# List available recipes
default:
    @just --list

# Create the cluster
up:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{justfile_directory()}}/terraform"
    tofu init -input=false
    tofu apply -var-file="local.tfvars" -auto-approve

# Destroy the cluster
down:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{justfile_directory()}}/terraform"
    tofu destroy -var-file="local.tfvars" -auto-approve

# Stop and remove all containers on the Terraform-managed network, remove the
# network, and delete local Terraform/OpenTofu state.
hard-reset cluster_name="cloudenv":
    #!/usr/bin/env bash
    set -euo pipefail
    network_name="{{cluster_name}}-net"
    echo "WARNING: this deletes containers on ${network_name}, the network, and local Terraform/OpenTofu state."
    read -r -p 'Type HARD RESET to continue: ' confirmation
    if [[ "$confirmation" != "HARD RESET" ]]; then
        echo "Hard reset cancelled."
        exit 1
    fi

    if docker network inspect "$network_name" >/dev/null 2>&1; then
        containers="$(docker ps -aq --filter "network=${network_name}")"
        if [[ -n "$containers" ]]; then
            docker stop $containers || true
            docker rm -f $containers
        fi
        docker network rm "$network_name"
    else
        echo "Docker network ${network_name} does not exist; skipping Docker cleanup."
    fi

    rm -f \
        "{{justfile_directory()}}/terraform/terraform.tfstate" \
        "{{justfile_directory()}}/terraform/terraform.tfstate.backup" \
        "{{justfile_directory()}}/terraform/.terraform.tfstate" \
        "{{justfile_directory()}}/terraform/.terraform.tfstate.backup" \
        "{{justfile_directory()}}/terraform/.terraform.tfstate.lock.info"
    echo "Hard reset complete."

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

# Configure the host DNS resolver so *.home.lab resolves via the dnsmasq container
setup-dns domain="home.lab" network_prefix="10.250.0":
    #!/usr/bin/env bash
    set -euo pipefail
    dns_server="{{network_prefix}}.3"
    case "$(uname -s)" in
        Darwin)
            sudo mkdir -p /etc/resolver
            printf "domain %s\nsearch %s\nnameserver %s\n" \
                "{{domain}}" "{{domain}}" "$dns_server" \
                | sudo tee /etc/resolver/{{domain}} > /dev/null
            ;;
        Linux)
            # systemd-resolved's ~ prefix makes this a routing-only domain;
            # DNS for all other domains continues using the normal resolvers.
            sudo mkdir -p /etc/systemd/resolved.conf.d
            printf "[Resolve]\nDNS=%s\nDomains=~%s\n" \
                "$dns_server" "{{domain}}" \
                | sudo tee /etc/systemd/resolved.conf.d/{{domain}}.conf > /dev/null
            sudo systemctl restart systemd-resolved
            sudo resolvectl flush-caches
            ;;
        *)
            echo "Unsupported operating system: $(uname -s)" >&2
            exit 1
            ;;
    esac
    echo "DNS resolver configured: *.{{domain}} -> $dns_server"
