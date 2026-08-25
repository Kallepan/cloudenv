output "name" {
  value = var.name
}

output "ip_address" {
  value = var.ip_address
}

output "port" {
  value = var.port
}

output "hostname" {
  value = var.hostname
}

output "kubeconfig_path" {
  value      = var.kubeconfig_path
  depends_on = [terraform_data.kubeconfig]
}
