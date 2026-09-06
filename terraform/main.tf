locals {
  kubeconfig_path            = abspath("${path.module}/../.configs/kubeconfig")
  automation_kubeconfig_path = abspath("${path.module}/../.configs/automation-kubeconfig")
  talosconfig_path           = abspath("${path.module}/../.configs/talosconfig")
  kcp_kubeconfig_path        = abspath("${path.module}/../.configs/kcp-kubeconfig")
  data_dir                   = abspath("${path.module}/../.data")

  network_prefix = var.network_prefix
  gateway_ip     = "${local.network_prefix}.1"

  # IP assigned by list position (starting at .2) — add a service here to
  # allocate it the next free address instead of hand-picking an octet
  service_names = ["haproxy", "dnsmasq", "registry", "openbao", "keycloak", "kcp", "seaweedfs"]
  service_ips = {
    for idx, svc in local.service_names :
    svc => "${local.network_prefix}.${idx + 2}"
  }

  haproxy_ip   = local.service_ips["haproxy"]
  dnsmasq_ip   = local.service_ips["dnsmasq"]
  registry_ip  = local.service_ips["registry"]
  openbao_ip   = local.service_ips["openbao"]
  keycloak_ip  = local.service_ips["keycloak"]
  kcp_ip       = local.service_ips["kcp"]
  seaweedfs_ip = local.service_ips["seaweedfs"]

  # Node IPs start at .10/.20, well clear of the service range above, so
  # growing service_names doesn't risk colliding with cluster nodes
  cp_nodes = [
    for i in range(var.control_plane_count) : {
      node_name    = "${var.cluster_name}-controlplane-${i}"
      ipv4_address = "${local.network_prefix}.${10 + i}"
    }
  ]
  worker_nodes = [
    for i in range(var.worker_count) : {
      node_name    = "${var.cluster_name}-worker-${i}"
      ipv4_address = "${local.network_prefix}.${20 + i}"
    }
  ]
}

module "network" {
  source  = "./modules/network"
  name    = "${var.cluster_name}-net"
  subnet  = "${local.network_prefix}.0/24"
  gateway = local.gateway_ip
}

module "certificates" {
  source   = "./modules/certificates"
  domain   = var.domain
  data_dir = local.data_dir
}

module "haproxy" {
  source       = "./modules/haproxy"
  name         = var.cluster_name
  tag          = var.haproxy_image_tag
  network_name = module.network.name
  ip_address   = local.haproxy_ip
  data_dir     = local.data_dir
  tls_cert     = module.certificates.cert
  tls_key      = module.certificates.key

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

  openbao = {
    domain       = "openbao.${var.domain}"
    ipv4_address = module.openbao.ip_address
    port         = module.openbao.port
  }

  keycloak = {
    domain       = "keycloak.${var.domain}"
    ipv4_address = module.keycloak.ip_address
    port         = module.keycloak.port
  }

  kcp = {
    domain       = "kcp.${var.domain}"
    ipv4_address = module.kcp.ip_address
    port         = module.kcp.port
  }

  seaweedfs = {
    domain       = "s3.${var.domain}"
    ipv4_address = module.seaweedfs.ip_address
    port         = module.seaweedfs.master_port
  }
}

module "dnsmasq" {
  source       = "./modules/dnsmasq"
  name         = var.cluster_name
  tag          = var.dnsmasq_image_tag
  network_name = module.network.name
  ip_address   = local.dnsmasq_ip
  data_dir     = local.data_dir
  domain       = var.domain
  resolve_to   = local.haproxy_ip
}

module "registry" {
  source         = "./modules/registry"
  name           = "registry"
  container_name = "${var.cluster_name}-registry"
  zot_version    = var.zot_image_tag
  network_name   = module.network.name
  ip_address     = local.registry_ip
  data_dir       = local.data_dir
  domain         = "registry.${var.domain}"
  tls_cert       = module.certificates.cert
  tls_key        = module.certificates.key
}

module "openbao" {
  source       = "./modules/openbao"
  name         = "${var.cluster_name}-openbao"
  tag          = var.openbao_image_tag
  network_name = module.network.name
  ip_address   = local.openbao_ip
  root_token   = var.openbao_root_token
}

module "keycloak" {
  source          = "./modules/keycloak"
  name            = "${var.cluster_name}-keycloak"
  tag             = var.keycloak_image_tag
  network_name    = module.network.name
  ip_address      = local.keycloak_ip
  data_dir        = local.data_dir
  hostname        = "keycloak.${var.domain}"
  admin_password  = var.keycloak_admin_password
  oidc_realm      = var.oidc_realm
  oidc_client_id  = var.oidc_client_id
  oidc_username   = var.oidc_username
  oidc_password   = var.oidc_user_password
  oidc_first_name = var.oidc_first_name
  oidc_last_name  = var.oidc_last_name
  oidc_user_email = var.oidc_user_email
}

module "kcp" {
  source          = "./modules/kcp"
  name            = "${var.cluster_name}-kcp"
  tag             = var.kcp_image_tag
  network_name    = module.network.name
  ip_address      = local.kcp_ip
  data_dir        = local.data_dir
  hostname        = "kcp.${var.domain}"
  tls_cert        = module.certificates.cert
  tls_key         = module.certificates.key
  root_ca         = module.certificates.root_ca
  kubeconfig_path = local.kcp_kubeconfig_path
}

module "seaweedfs" {
  source        = "./modules/seaweedfs"
  name          = "${var.cluster_name}-seaweedfs"
  tag           = var.seaweedfs_image_tag
  network_name  = module.network.name
  ip_address    = local.seaweedfs_ip
  data_dir      = local.data_dir
  hostname      = "s3.${var.domain}"
  s3_access_key = var.seaweedfs_s3_access_key
  s3_secret_key = var.seaweedfs_s3_secret_key
}

module "cluster" {
  source = "./modules/cluster"

  cluster_name               = var.cluster_name
  network_name               = module.network.name
  network_prefix             = local.network_prefix
  worker_count               = var.worker_count
  control_plane_count        = var.control_plane_count
  domain                     = var.domain
  kubeconfig_path            = local.kubeconfig_path
  automation_kubeconfig_path = local.automation_kubeconfig_path
  talosconfig_path           = local.talosconfig_path
  talos_version              = var.talos_version
  kubernetes_version         = var.kubernetes_version
  root_ca                    = module.certificates.root_ca
  oidc_issuer_url            = "https://keycloak.${var.domain}/realms/${var.oidc_realm}"
  oidc_host                  = "keycloak.${var.domain}"
  oidc_client_id             = var.oidc_client_id
  oidc_username              = var.oidc_username
  oidc_host_ip               = local.haproxy_ip
}

module "flux" {
  count  = var.enable_flux ? 1 : 0
  source = "./modules/flux"

  kubeconfig_path    = module.cluster.automation_kubeconfig_path
  kubeconfig_raw     = module.cluster.kubeconfig_raw
  cluster_generation = module.cluster.cluster_generation
  data_dir           = local.data_dir
  git_url            = var.flux_git_url
  git_branch         = var.flux_git_branch
  git_path           = var.flux_git_path

  registry_domain = module.registry.domain
  manifests_path  = abspath("${path.module}/../manifests")
  root_ca         = module.certificates.root_ca
}

