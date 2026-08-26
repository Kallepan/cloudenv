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
}

# SeaweedFS S3 identity config — static credentials for local dev use
resource "local_file" "s3_config" {
  content = jsonencode({
    identities = [{
      name = "admin"
      credentials = [{
        accessKey = var.s3_access_key
        secretKey = var.s3_secret_key
      }]
      actions = ["Admin", "Read", "Write"]
    }]
  })
  filename        = "${local.config_dir}/s3_config.json"
  file_permission = "0600"
}

resource "docker_volume" "data" {
  name = "${var.name}-data"
}

# Checking the remote digest (rather than trusting the locally cached tag)
# means a new image gets pulled on the next apply automatically
data "docker_registry_image" "seaweedfs" {
  name = "${var.image}:${var.tag}"
}

resource "docker_image" "seaweedfs" {
  name          = data.docker_registry_image.seaweedfs.name
  pull_triggers = [data.docker_registry_image.seaweedfs.sha256_digest]
  keep_locally  = true
}

# Single "server" process runs master (web UI), volume, filer, and S3 API together
resource "docker_container" "seaweedfs" {
  depends_on = [local_file.s3_config, docker_image.seaweedfs]

  name     = var.name
  hostname = var.name
  image    = docker_image.seaweedfs.image_id
  restart  = "unless-stopped"

  command = [
    "server",
    "-dir=/data",
    "-ip=${var.name}",
    "-master.port=${var.master_port}",
    "-volume.port=${var.volume_port}",
    "-filer",
    "-filer.port=${var.filer_port}",
    "-s3",
    "-s3.port=${var.s3_port}",
    "-s3.config=/etc/seaweedfs/s3_config.json",
  ]

  volumes {
    host_path      = local_file.s3_config.filename
    container_path = "/etc/seaweedfs/s3_config.json"
    read_only      = true
  }

  volumes {
    volume_name    = docker_volume.data.name
    container_path = "/data"
  }

  networks_advanced {
    name         = var.network_name
    ipv4_address = var.ip_address
  }
}
