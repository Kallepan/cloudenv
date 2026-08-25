terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

resource "docker_image" "openbao" {
  name         = "${var.image}:${var.tag}"
  keep_locally = true
}

# Dev-mode server: in-memory storage, auto-unsealed, root token fixed — local testing only
resource "docker_container" "openbao" {
  name     = var.name
  hostname = var.name
  image    = docker_image.openbao.image_id
  restart  = "unless-stopped"

  command = [
    "server",
    "-dev",
    "-dev-root-token-id=${var.root_token}",
    "-dev-listen-address=0.0.0.0:${var.port}",
  ]

  env = [
    "BAO_LOG_LEVEL=info",
  ]

  networks_advanced {
    name         = var.network_name
    ipv4_address = var.ip_address
  }
}
