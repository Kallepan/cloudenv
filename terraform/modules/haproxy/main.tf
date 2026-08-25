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
    tls_cert_path = local.has_tls ? "/usr/local/etc/haproxy/certs/wildcard.pem" : null
  })
  filename = "/tmp/haproxy-${var.name}/haproxy.cfg"
}

locals {
  has_tls = var.tls_cert != "" && var.tls_key != ""
}

# HAProxy expects cert + key concatenated in a single PEM file for "bind ... ssl crt"
resource "local_file" "tls_bundle" {
  count           = local.has_tls ? 1 : 0
  content         = "${var.tls_cert}\n${var.tls_key}"
  filename        = "/tmp/haproxy-${var.name}/certs/wildcard.pem"
  file_permission = "0600"
}

resource "docker_image" "haproxy" {
  name         = "haproxy:lts"
  keep_locally = true
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
    host_path      = "/tmp/haproxy-${var.name}"
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
