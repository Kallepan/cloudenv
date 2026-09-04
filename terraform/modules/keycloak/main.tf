terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

locals {
  config_dir = "${var.data_dir}/${var.name}"
  realm_config = jsonencode({
    realm       = var.oidc_realm
    enabled     = true
    sslRequired = "none"
    clients = [{
      clientId                  = var.oidc_client_id
      enabled                   = true
      publicClient              = true
      standardFlowEnabled       = true
      directAccessGrantsEnabled = true
      redirectUris              = ["http://localhost:*", "http://127.0.0.1:*"]
      webOrigins                = ["*"]
      attributes = {
        "pkce.code.challenge.method" = "S256"
      }
    }]
    users = [{
      username      = var.oidc_username
      firstName     = var.oidc_first_name
      lastName      = var.oidc_last_name
      email         = var.oidc_user_email
      enabled       = true
      emailVerified = true
      credentials = [{
        type      = "password"
        value     = var.oidc_password
        temporary = false
      }]
    }]
  })
}

resource "local_file" "realm" {
  content         = local.realm_config
  filename        = "${local.config_dir}/realm.json"
  file_permission = "0600"
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
  depends_on = [local_file.realm]

  name     = var.name
  hostname = var.name
  image    = docker_image.keycloak.image_id
  restart  = "unless-stopped"

  command = ["start-dev", "--http-port=${var.port}", "--import-realm"]

  env = [
    "KC_BOOTSTRAP_ADMIN_USERNAME=${var.admin_user}",
    "KC_BOOTSTRAP_ADMIN_PASSWORD=${var.admin_password}",
    # Keycloak sits behind HAProxy's TLS termination — without these it generates
    # http:// URLs for its login iframe/cookies, breaking the 3rd-party check
    "KC_PROXY_HEADERS=xforwarded",
    "KC_HOSTNAME=https://${var.hostname}",
    "OIDC_REALM_CONFIG_HASH=${md5(local.realm_config)}",
  ]

  volumes {
    host_path      = local_file.realm.filename
    container_path = "/opt/keycloak/data/import/realm.json"
    read_only      = true
  }

  networks_advanced {
    name         = var.network_name
    ipv4_address = var.ip_address
  }
}
