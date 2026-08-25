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
  config_dir     = "${var.data_dir}/${var.name}-registry"
  container_name = coalesce(var.container_name, "${var.name}-registry")
}

resource "docker_volume" "data" {
  name = "${var.name}-registry-data"
}

# Write TLS material to a temp path that the container mounts read-only
resource "local_file" "cert" {
  content         = var.tls_cert
  filename        = "${local.config_dir}/cert.pem"
  file_permission = "0644"
}

resource "local_file" "key" {
  content         = var.tls_key
  filename        = "${local.config_dir}/cert.key"
  file_permission = "0600"
}

resource "local_file" "config" {
  content = templatefile("${path.module}/templates/config.json.tpl", {
    port         = var.port
    mirror       = var.mirror
    sync_prefill = var.sync_prefill
  })
  filename        = "${local.config_dir}/config.json"
  file_permission = "0644"
}

# zot requires a credentials file to exist when sync is enabled, even if empty
resource "local_file" "sync_creds" {
  count           = var.mirror ? 1 : 0
  content         = jsonencode({})
  filename        = "${local.config_dir}/sync-creds.json"
  file_permission = "0600"
}

resource "docker_image" "zot" {
  name         = "ghcr.io/project-zot/zot:${var.zot_version}"
  keep_locally = true
}

resource "docker_container" "registry" {
  depends_on = [
    local_file.cert,
    local_file.key,
    local_file.config,
    docker_image.zot,
  ]

  name    = local.container_name
  image   = docker_image.zot.image_id
  restart = "unless-stopped"
  command = ["serve", "/etc/zot/config.json"]

  networks_advanced {
    name         = var.network_name
    ipv4_address = var.ip_address
  }

  volumes {
    host_path      = local.config_dir
    container_path = "/etc/docker/registry"
    read_only      = true
  }

  volumes {
    host_path      = "${local.config_dir}/config.json"
    container_path = "/etc/zot/config.json"
    read_only      = true
  }

  dynamic "volumes" {
    for_each = var.mirror ? [1] : []
    content {
      host_path      = "${local.config_dir}/sync-creds.json"
      container_path = "/etc/zot/sync-creds.json"
      read_only      = true
    }
  }

  volumes {
    volume_name    = docker_volume.data.name
    container_path = "/var/lib/registry"
  }
}
