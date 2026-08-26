output "name" {
  value = var.name
}

output "ip_address" {
  value = var.ip_address
}

output "port" {
  value = var.port
}

output "admin_user" {
  value = var.admin_user
}

output "admin_password" {
  value     = var.admin_password
  sensitive = true
}
