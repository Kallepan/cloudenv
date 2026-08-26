terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Checking the remote digest (rather than trusting the locally cached tag)
# means a new image gets pulled on the next apply automatically
data "docker_registry_image" "keycloak" {
  name = "${var.image}:${var.tag}"
}

resource "docker_image" "keycloak" {
  name          = data.docker_registry_image.keycloak.name
  pull_triggers = [data.docker_registry_image.keycloak.sha256_digest]
  keep_locally  = true
}

# Dev-mode server: in-memory H2 storage, fixed admin credentials — local testing only
resource "docker_container" "keycloak" {
  name     = var.name
  hostname = var.name
  image    = docker_image.keycloak.image_id
  restart  = "unless-stopped"

  command = ["start-dev", "--http-port=${var.port}"]

  env = [
    "KC_BOOTSTRAP_ADMIN_USERNAME=${var.admin_user}",
    "KC_BOOTSTRAP_ADMIN_PASSWORD=${var.admin_password}",
    # Keycloak sits behind HAProxy's TLS termination — without these it generates
    # http:// URLs for its login iframe/cookies, breaking the 3rd-party check
    "KC_PROXY_HEADERS=xforwarded",
    "KC_HOSTNAME=https://${var.hostname}",
  ]

  networks_advanced {
    name         = var.network_name
    ipv4_address = var.ip_address
  }
}
