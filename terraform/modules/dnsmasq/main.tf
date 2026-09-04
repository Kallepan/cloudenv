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

resource "local_file" "conf" {
  content  = templatefile("${path.module}/templates/dnsmasq.conf.tpl", {
    domain       = var.domain
    resolve_to   = var.resolve_to
    upstream_dns = var.upstream_dns
    extra_hosts  = var.extra_hosts
  })
  filename = "${var.data_dir}/dnsmasq-${var.domain}/dnsmasq.conf"
}

# Checking the remote digest (rather than trusting the locally cached "latest"
# tag) means a new image gets pulled on the next apply automatically
data "docker_registry_image" "dnsmasq" {
  name = "andyshinn/dnsmasq:${var.tag}"
}

resource "docker_image" "dnsmasq" {
  name          = data.docker_registry_image.dnsmasq.name
  pull_triggers = [data.docker_registry_image.dnsmasq.sha256_digest]
  keep_locally  = true
}

resource "docker_container" "dnsmasq" {
  depends_on = [local_file.conf, docker_image.dnsmasq]

  name    = var.name == "dnsmasq" ? "dnsmasq" : "${var.name}-dnsmasq"
  image   = docker_image.dnsmasq.image_id
  restart = "unless-stopped"

  capabilities {
    add = ["NET_ADMIN"]
  }

  command = ["--conf-file=/etc/dnsmasq/dnsmasq.conf", "--no-daemon"]

  networks_advanced {
    name         = var.network_name
    ipv4_address = var.ip_address
  }

  volumes {
    host_path      = "${var.data_dir}/dnsmasq-${var.domain}"
    container_path = "/etc/dnsmasq"
    read_only      = true
  }
}
