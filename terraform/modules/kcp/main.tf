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
  config_dir = "${var.data_dir}/${var.name}"
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

  # sha1 of the script itself ensures edits to it trigger a rerun even though
  # the container id (the only "real" input) hasn't changed
  triggers_replace = [
    docker_container.kcp.id,
    var.kubeconfig_path,
    sha1(file("${path.module}/scripts/extract-kubeconfig.sh")),
  ]

  provisioner "local-exec" {
    command = "bash \"${path.module}/scripts/extract-kubeconfig.sh\""
    environment = {
      KCP_CONTAINER = var.name
      KCP_SRC       = "/data/.kcp/admin.kubeconfig"
      KCP_DST       = var.kubeconfig_path
      KCP_HOSTNAME  = var.hostname
      KCP_PORT      = tostring(var.port)
    }
  }
}
