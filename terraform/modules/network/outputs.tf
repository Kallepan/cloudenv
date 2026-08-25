output "name" {
  value = docker_network.this.name
}

output "id" {
  value = docker_network.this.id
}

output "subnet" {
  value = var.subnet
}

output "gateway" {
  value = var.gateway
}
