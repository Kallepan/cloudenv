terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

resource "docker_network" "this" {
  name = var.name

  ipam_config {
    subnet  = var.subnet
    gateway = var.gateway
  }
}
