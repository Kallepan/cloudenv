locals {
  all_nodes = merge(
    {
      for i in range(var.control_plane_count) :
      "${var.cluster_name}-controlplane-${i}" => {
        role  = "controlplane"
        index = i
        ip    = "10.5.0.${10 + i}"
      }
    },
    {
      for i in range(var.worker_count) :
      "${var.cluster_name}-worker-${i}" => {
        role  = "worker"
        index = i
        ip    = "10.5.0.${20 + i}"
      }
    }
  )

  cp_nodes     = { for k, v in local.all_nodes : k => v if v.role == "controlplane" }
  worker_nodes = { for k, v in local.all_nodes : k => v if v.role == "worker" }
  cp_ips       = [for k, v in local.cp_nodes : v.ip]
  worker_ips   = [for k, v in local.worker_nodes : v.ip]

  bootstrap_ip     = local.cp_nodes["${var.cluster_name}-controlplane-0"].ip
  # Direct IP so Talos nodes can reach the API server without DNS during bootstrap
  cluster_endpoint = "https://${local.bootstrap_ip}:6443"
  talos_image      = "ghcr.io/siderolabs/talos:${var.talos_version}"

  root_ca_patch = var.root_ca != "" ? yamlencode({
    apiVersion   = "v1alpha1"
    kind         = "TrustedRootsConfig"
    name         = "local-root-ca"
    certificates = var.root_ca
  }) : null

  common_patches = compact([local.root_ca_patch])
}

# ── Secrets ───────────────────────────────────────────────────────────────────

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

# ── Docker infrastructure ─────────────────────────────────────────────────────

resource "docker_image" "talos" {
  name         = local.talos_image
  keep_locally = true
}

resource "docker_volume" "node" {
  for_each = local.all_nodes
  name     = "${each.key}-var"
}

# Nodes start in maintenance mode — talos provider applies config below
# No host port mappings: HAProxy handles ingress; docker-mac-net-connect gives direct IP access
resource "docker_container" "node" {
  for_each   = local.all_nodes
  depends_on = [docker_image.talos]

  name       = each.key
  hostname   = each.key
  image      = docker_image.talos.image_id
  restart    = "unless-stopped"

  env = ["PLATFORM=container"]

  networks_advanced {
    name         = var.network_name
    ipv4_address = each.value.ip
  }

  privileged = true
  read_only  = true
  security_opts = [
    "label=disable",
    "seccomp=unconfined",
  ]

  mounts {
    target = "/run"
    type   = "tmpfs"
  }

  mounts {
    target = "/system"
    type   = "tmpfs"
  }

  mounts {
    target = "/tmp"
    type   = "tmpfs"
  }

  mounts {
    target = "/system/state"
    type   = "volume"
  }

  mounts {
    source = docker_volume.node[each.key].name
    target = "/var"
    type   = "volume"
  }

  mounts {
    target = "/etc/cni"
    type   = "volume"
  }

  mounts {
    target = "/etc/kubernetes"
    type   = "volume"
  }

  mounts {
    target = "/usr/libexec/kubernetes"
    type   = "volume"
  }

  mounts {
    target = "/opt"
    type   = "volume"
  }
}

# ── Control plane configuration ───────────────────────────────────────────────

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.cluster_name
  machine_type       = "controlplane"
  cluster_endpoint   = local.cluster_endpoint
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = concat(
    [
      jsonencode({
        cluster = {
          # Single control plane must also schedule workloads
          allowSchedulingOnControlPlanes = var.control_plane_count == 1
        }
      })
    ],
    local.common_patches
  )
}

resource "talos_machine_configuration_apply" "controlplane" {
  for_each   = local.cp_nodes
  depends_on = [docker_container.node]

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  endpoint                    = each.value.ip
  node                        = each.value.ip
}

# ── Bootstrap ─────────────────────────────────────────────────────────────────

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = local.bootstrap_ip
  node                 = local.bootstrap_ip
}

# Prevents bootstrap from re-running on subsequent applies
resource "terraform_data" "bootstrap_gate" {
  input = talos_machine_bootstrap.this.id

  lifecycle {
    ignore_changes = [input]
  }
}

# ── Worker configuration ──────────────────────────────────────────────────────

data "talos_machine_configuration" "worker" {
  cluster_name       = var.cluster_name
  machine_type       = "worker"
  cluster_endpoint   = local.cluster_endpoint
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = local.common_patches
}

resource "talos_machine_configuration_apply" "worker" {
  for_each = local.worker_nodes

  depends_on = [
    docker_container.node,
    terraform_data.bootstrap_gate,
  ]

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  endpoint                    = each.value.ip
  node                        = each.value.ip
}

# ── Health + kubeconfig ───────────────────────────────────────────────────────

data "talos_cluster_health" "this" {
  depends_on = [
    talos_machine_configuration_apply.worker,
    terraform_data.bootstrap_gate,
  ]

  client_configuration = talos_machine_secrets.this.client_configuration
  control_plane_nodes  = local.cp_ips
  worker_nodes         = local.worker_ips
  endpoints            = local.cp_ips

  timeouts = {
    read = "10m"
  }
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [data.talos_cluster_health.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.bootstrap_ip
}

resource "local_file" "kubeconfig" {
  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = var.kubeconfig_path
  file_permission = "0600"
}

# ── talosconfig ───────────────────────────────────────────────────────────────

locals {
  talosconfig_raw = yamlencode({
    context = var.cluster_name
    contexts = {
      (var.cluster_name) = {
        endpoints = local.cp_ips
        nodes     = concat(local.cp_ips, local.worker_ips)
        ca        = talos_machine_secrets.this.client_configuration.ca_certificate
        crt       = talos_machine_secrets.this.client_configuration.client_certificate
        key       = talos_machine_secrets.this.client_configuration.client_key
      }
    }
  })
}

resource "local_file" "talosconfig" {
  content         = local.talosconfig_raw
  filename        = var.talosconfig_path
  file_permission = "0600"
}
