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
  content  = templatefile("${path.module}/templates/haproxy.cfg.tpl", {
    clusters   = var.clusters
    registries = var.registries
    kcp        = var.kcp
    dex        = var.dex
    openbao    = var.openbao
  })
  filename = "/tmp/haproxy-${var.name}/haproxy.cfg"
}

resource "docker_image" "haproxy" {
  name         = "haproxy:lts"
  keep_locally = true
}

resource "docker_container" "haproxy" {
  depends_on = [local_file.cfg, docker_image.haproxy]

  name    = "haproxy-${var.name}"
  image   = docker_image.haproxy.image_id
  restart = "unless-stopped"

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
