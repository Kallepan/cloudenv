output "cluster_name" {
  value = var.cluster_name
}

output "kubeconfig_path" {
  value = var.kubeconfig_path
}

output "talosconfig_path" {
  value = var.talosconfig_path
}

output "kubeconfig_raw" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

output "controlplane_nodes" {
  description = "Control plane node list for haproxy backend configuration"
  value = [
    for k, v in local.cp_nodes : {
      node_name    = k
      ipv4_address = v.ip
    }
  ]
}

output "worker_nodes" {
  description = "Worker node list for haproxy backend configuration"
  value = [
    for k, v in local.worker_nodes : {
      node_name    = k
      ipv4_address = v.ip
    }
  ]
}
