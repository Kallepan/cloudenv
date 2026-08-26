output "name" {
  value = var.name
}

output "ip_address" {
  value = var.ip_address
}

output "port" {
  value = var.port
}

output "root_token" {
  value     = var.root_token
  sensitive = true
}
