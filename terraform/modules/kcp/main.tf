terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

locals {
  config_dir = "/tmp/${var.name}"
  # Append the CA after the server cert to provide the full chain when needed
  cert_bundle = trimspace(join("\n", compact([var.tls_cert, var.root_ca])))
}

resource "local_file" "tls_cert" {
  content         = local.cert_bundle
  filename        = "${local.config_dir}/tls.crt"
  file_permission = "0644"
}

resource "local_file" "tls_key" {
  content         = var.tls_key
  filename        = "${local.config_dir}/tls.key"
  file_permission = "0600"
}

resource "docker_image" "kcp" {
  name         = "${var.image}:${var.tag}"
  keep_locally = true
}

# kcp terminates its own TLS — HAProxy passes it through by SNI rather than
# terminating locally like openbao/keycloak.
resource "docker_container" "kcp" {
  depends_on = [local_file.tls_cert, local_file.tls_key, docker_image.kcp]

  name     = var.name
  hostname = var.name
  image    = docker_image.kcp.image_id
  restart  = "unless-stopped"

  command = concat(
    [
      "start",
      "--secure-port=${var.port}",
      "--shard-base-url=https://${var.hostname}:${var.port}",
      "--shard-external-url=https://${var.hostname}:${var.port}",
      "--shard-virtual-workspace-url=https://${var.hostname}:${var.port}",
      "--tls-cert-file=/etc/kcp/tls.crt",
      "--tls-private-key-file=/etc/kcp/tls.key",
    ],
    var.oidc != null ? [
      "--oidc-issuer-url=${var.oidc.issuer_url}",
      "--oidc-client-id=${var.oidc.client_id}",
      "--oidc-username-claim=${var.oidc.username_claim}",
      "--oidc-groups-claim=${var.oidc.groups_claim}",
    ] : [],
    var.oidc != null && var.oidc.ca_cert != null ? [
      "--oidc-ca-file=/etc/kcp/oidc-ca.crt",
    ] : []
  )

  dynamic "upload" {
    for_each = var.oidc != null && var.oidc.ca_cert != null ? [var.oidc.ca_cert] : []
    content {
      content = upload.value
      file    = "/etc/kcp/oidc-ca.crt"
    }
  }

  volumes {
    host_path      = local_file.tls_cert.filename
    container_path = "/etc/kcp/tls.crt"
    read_only      = true
  }

  volumes {
    host_path      = local_file.tls_key.filename
    container_path = "/etc/kcp/tls.key"
    read_only      = true
  }

  networks_advanced {
    name         = var.network_name
    ipv4_address = var.ip_address
  }
}

# kcp writes its own admin.kubeconfig at runtime — pull it out once the
# container is ready rather than trying to predict/inject it beforehand.
resource "terraform_data" "kubeconfig" {
  depends_on = [docker_container.kcp]

  triggers_replace = [docker_container.kcp.id]

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail

      dst="${var.kubeconfig_path}"
      tmp="$${dst}.tmp"
      container="${var.name}"
      src="/data/.kcp/admin.kubeconfig"

      mkdir -p "$(dirname "$${dst}")"

      # Wait for kcp to generate the admin kubeconfig inside the container.
      max_attempts=60
      attempt=1
      until docker exec "$${container}" sh -lc "test -f '$${src}'" >/dev/null 2>&1; do
        if [ "$${attempt}" -ge "$${max_attempts}" ]; then
          echo "Timed out waiting for $${src} in container $${container}" >&2
          docker logs "$${container}" 2>&1 | tail -n 80 >&2 || true
          exit 1
        fi
        attempt=$((attempt + 1))
        sleep 2
      done

      docker cp "$${container}:$${src}" "$${tmp}"

      # kcp's own kubeconfig points at its internal Docker IP, but the mkcert
      # cert only covers *.home.lab — rewrite each cluster to the HAProxy
      # passthrough hostname on :6443 so TLS verification succeeds.
      KUBECONFIG="$${tmp}" kubectl config set-cluster root --server="https://${var.hostname}:${var.port}/clusters/root" >/dev/null || true
      KUBECONFIG="$${tmp}" kubectl config set-cluster base --server="https://${var.hostname}:${var.port}" >/dev/null || true
      KUBECONFIG="$${tmp}" kubectl config set-cluster system:admin --server="https://${var.hostname}:${var.port}/clusters/system:admin" >/dev/null || true

      mv "$${tmp}" "$${dst}"
      chmod 0644 "$${dst}"
    EOT
  }
}
