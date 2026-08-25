output "cluster_name" {
  value = module.cluster.cluster_name
}

output "kubeconfig_path" {
  description = "Absolute path to the written kubeconfig"
  value       = module.cluster.kubeconfig_path
}

output "talosconfig_path" {
  description = "Absolute path to the written talosconfig"
  value       = module.cluster.talosconfig_path
}
