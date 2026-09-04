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

resource "local_file" "cfg" {
  content = templatefile("${path.module}/templates/haproxy.cfg.tpl", {
    clusters      = var.clusters
    registries    = var.registries
    openbao       = var.openbao
    keycloak      = var.keycloak
    kcp           = var.kcp
    seaweedfs     = var.seaweedfs
    tls_cert_path = local.has_tls ? "/usr/local/etc/haproxy/certs/wildcard.pem" : null
  })
  filename = "${var.data_dir}/haproxy-${var.name}/haproxy.cfg"

  # clusters/registries/openbao/keycloak/kcp/seaweedfs all contribute a
  # "<name>_http"-style backend to the rendered config — a collision between
  # any two silently produces an invalid haproxy.cfg that only fails at
  # container start.
  lifecycle {
    precondition {
      condition     = length(local.all_backend_names) == length(distinct(local.all_backend_names))
      error_message = "Duplicate HAProxy backend identifier among clusters/registries/openbao/keycloak/kcp/seaweedfs: ${join(", ", local.all_backend_names)}. Each must be unique."
    }
    precondition {
      condition     = local.has_tls || (var.openbao == null && var.keycloak == null && var.seaweedfs == null)
      error_message = "openbao/keycloak/seaweedfs require HAProxy TLS termination; set tls_cert and tls_key (or unset them)."
    }
  }
}

locals {
  has_tls = var.tls_cert != "" && var.tls_key != ""

  all_backend_names = concat(
    [for c in var.clusters : c.name],
    [for r in var.registries : r.name],
    var.openbao != null ? ["openbao"] : [],
    var.keycloak != null ? ["keycloak"] : [],
    var.kcp != null ? ["kcp"] : [],
    var.seaweedfs != null ? ["seaweedfs"] : [],
  )
}

# HAProxy expects cert + key concatenated in a single PEM file for "bind ... ssl crt"
resource "local_file" "tls_bundle" {
  count           = local.has_tls ? 1 : 0
  content         = "${var.tls_cert}\n${var.tls_key}"
  filename        = "${var.data_dir}/haproxy-${var.name}/certs/wildcard.pem"
  file_permission = "0600"
}

# Checking the remote digest (rather than trusting the locally cached "lts"
# tag) means a new haproxy release gets pulled on the next apply automatically
data "docker_registry_image" "haproxy" {
  name = "haproxy:${var.tag}"
}

resource "docker_image" "haproxy" {
  name          = data.docker_registry_image.haproxy.name
  pull_triggers = [data.docker_registry_image.haproxy.sha256_digest]
  keep_locally  = true
}

resource "docker_container" "haproxy" {
  depends_on = [local_file.cfg, local_file.tls_bundle, docker_image.haproxy]

  name    = "${var.name}-haproxy"
  image   = docker_image.haproxy.image_id
  restart = "unless-stopped"

  # Config changes don't trigger a container refresh on their own — force
  # recreation so haproxy picks up the new config/certs on every apply
  env = ["CONFIG_HASH=${md5(local_file.cfg.content)}"]

  networks_advanced {
    name         = var.network_name
    ipv4_address = var.ip_address
  }

  volumes {
    host_path      = "${var.data_dir}/haproxy-${var.name}"
    container_path = "/usr/local/etc/haproxy"
    read_only      = true
  }

  ports {
    internal = 80
    external = 80
    protocol = "tcp"
  }

  ports {
    internal = 443
    external = 443
    protocol = "tcp"
  }

  ports {
    internal = 6443
    external = 6443
    protocol = "tcp"
  }

  ports {
    internal = 8404
    external = 8404
    protocol = "tcp"
  }
}
