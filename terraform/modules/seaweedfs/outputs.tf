output "name" {
  value = var.name
}

output "ip_address" {
  value = var.ip_address
}

output "master_port" {
  value = var.master_port
}

output "s3_port" {
  value = var.s3_port
}

output "filer_port" {
  value = var.filer_port
}

output "hostname" {
  value = var.hostname
}

output "s3_access_key" {
  value = var.s3_access_key
}

output "s3_secret_key" {
  value     = var.s3_secret_key
  sensitive = true
}
