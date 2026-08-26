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

output "kcp_kubeconfig_path" {
  description = "Absolute path to kcp's generated admin.kubeconfig"
  value       = module.kcp.kubeconfig_path
}

output "openbao_addr" {
  description = "OpenBao address, exposed via HAProxy TLS termination"
  value       = "https://openbao.${var.domain}"
}

output "keycloak_addr" {
  description = "Keycloak address, exposed via HAProxy TLS termination"
  value       = "https://keycloak.${var.domain}"
}

output "kcp_addr" {
  description = "kcp address, exposed via HAProxy TLS passthrough on 6443"
  value       = "https://kcp.${var.domain}:6443"
}

output "seaweedfs_ui_addr" {
  description = "SeaweedFS master web UI, exposed via HAProxy TLS termination"
  value       = "https://s3.${var.domain}"
}

output "seaweedfs_s3_endpoint" {
  description = "SeaweedFS S3 API — reach directly by container IP (not proxied through HAProxy)"
  value       = "http://${module.seaweedfs.ip_address}:${module.seaweedfs.s3_port}"
}
