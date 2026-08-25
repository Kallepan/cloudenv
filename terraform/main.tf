locals {
  kubeconfig_path  = abspath("${path.module}/../.configs/kubeconfig")
  talosconfig_path = abspath("${path.module}/../.configs/talosconfig")

  # Fixed IP scheme within 10.5.0.0/24
  # .1   = gateway
  # .2   = haproxy
  # .3   = dnsmasq
  # .4   = registry
  # .10+ = control planes
  # .20+ = workers
  haproxy_ip  = "10.5.0.2"
  dnsmasq_ip  = "10.5.0.3"
  registry_ip = "10.5.0.4"

  # Pre-compute node IPs to break Terraform dependency cycle:
  # haproxy config can be generated before the cluster is applied
  cp_nodes = [
    for i in range(var.control_plane_count) : {
      node_name    = "${var.cluster_name}-controlplane-${i}"
      ipv4_address = "10.5.0.${10 + i}"
    }
  ]
  worker_nodes = [
    for i in range(var.worker_count) : {
      node_name    = "${var.cluster_name}-worker-${i}"
      ipv4_address = "10.5.0.${20 + i}"
    }
  ]
}

module "network" {
  source  = "./modules/network"
  name    = "${var.cluster_name}-net"
  subnet  = "10.5.0.0/24"
  gateway = "10.5.0.1"
}

module "certificates" {
  source = "./modules/certificates"
  domain = var.domain
}

module "haproxy" {
  source       = "./modules/haproxy"
  name         = var.cluster_name
  network_name = module.network.name
  ip_address   = local.haproxy_ip

  clusters = [{
    name          = var.cluster_name
    base_domain   = var.domain
    api_domain    = "kube.${var.cluster_name}.${var.domain}"
    controlplanes = local.cp_nodes
    workers       = local.worker_nodes
    ports = {
      k8s   = 6443
      http  = 80
      https = 443
    }
  }]

  registries = [{
    name         = module.registry.name
    domain       = module.registry.domain
    ipv4_address = module.registry.ip_address
    port         = module.registry.port
  }]
}

module "dnsmasq" {
  source       = "./modules/dnsmasq"
  network_name = module.network.name
  ip_address   = local.dnsmasq_ip
  domain       = var.domain
  resolve_to   = local.haproxy_ip
}

module "registry" {
  source       = "./modules/registry"
  name         = "registry"
  network_name = module.network.name
  ip_address   = local.registry_ip
  domain       = "registry.${var.domain}"
  tls_cert     = module.certificates.cert
  tls_key      = module.certificates.key
}

module "cluster" {
  source = "./modules/cluster"

  cluster_name        = var.cluster_name
  network_name        = module.network.name
  worker_count        = var.worker_count
  control_plane_count = var.control_plane_count
  domain              = var.domain
  kubeconfig_path     = local.kubeconfig_path
  talosconfig_path    = local.talosconfig_path
  talos_version       = var.talos_version
  kubernetes_version  = var.kubernetes_version
  root_ca             = module.certificates.root_ca
}

module "flux" {
  count  = var.enable_flux ? 1 : 0
  source = "./modules/flux"

  kubeconfig_path = local.kubeconfig_path
  kubeconfig_raw  = module.cluster.kubeconfig_raw
  git_url         = var.flux_git_url
  git_branch      = var.flux_git_branch
  git_path        = var.flux_git_path
}

