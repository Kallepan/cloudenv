output "ip_address" {
  value = var.ip_address
}

output "container_name" {
  value = docker_container.haproxy.name
}
