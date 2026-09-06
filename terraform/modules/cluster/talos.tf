locals {
  all_nodes = merge(
    {
      for i in range(var.control_plane_count) :
      "${var.cluster_name}-controlplane-${i}" => {
        role  = "controlplane"
        index = i
        ip    = "${var.network_prefix}.${10 + i}"
      }
    },
    {
      for i in range(var.worker_count) :
      "${var.cluster_name}-worker-${i}" => {
        role  = "worker"
        index = i
        ip    = "${var.network_prefix}.${20 + i}"
      }
    }
  )

  cp_nodes     = { for k, v in local.all_nodes : k => v if v.role == "controlplane" }
  worker_nodes = { for k, v in local.all_nodes : k => v if v.role == "worker" }
  cp_ips       = [for k, v in local.cp_nodes : v.ip]
  worker_ips   = [for k, v in local.worker_nodes : v.ip]

  bootstrap_ip = local.cp_nodes["${var.cluster_name}-controlplane-0"].ip
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

# Changes to core cluster parameters start from a clean Talos cluster.
resource "terraform_data" "cluster_parameters" {
  triggers_replace = [
    var.cluster_name,
    var.network_name,
    var.network_prefix,
    var.domain,
    var.worker_count,
    var.control_plane_count,
    var.oidc_issuer_url,
    var.oidc_client_id,
    var.oidc_username,
    var.oidc_host,
    var.oidc_host_ip,
    var.talos_version,
    var.kubernetes_version,
    var.root_ca,
  ]
}

# ── Secrets ───────────────────────────────────────────────────────────────────

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version

  lifecycle {
    replace_triggered_by = [terraform_data.cluster_parameters]
  }
}

# ── Docker infrastructure ─────────────────────────────────────────────────────

resource "docker_image" "talos" {
  name         = local.talos_image
  keep_locally = true

  lifecycle {
    replace_triggered_by = [terraform_data.cluster_parameters]
  }
}

resource "docker_volume" "node" {
  for_each = local.all_nodes
  name     = "${each.key}-var"

  lifecycle {
    replace_triggered_by = [terraform_data.cluster_parameters]
  }
}

# Nodes start in maintenance mode — talos provider applies config below
# No host port mappings: HAProxy handles ingress; docker-mac-net-connect gives direct IP access
resource "docker_container" "node" {
  for_each   = local.all_nodes
  depends_on = [docker_image.talos]

  lifecycle {
    replace_triggered_by = [terraform_data.cluster_parameters]
  }

  name     = each.key
  hostname = each.key
  image    = docker_image.talos.image_id
  restart  = "unless-stopped"

  env = ["PLATFORM=container"]

  host {
    host = var.oidc_host
    ip   = var.oidc_host_ip
  }

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
        machine = var.root_ca != "" ? {
          files = [{
            content     = var.root_ca
            permissions = 420
            path        = "/var/etc/kubernetes/oidc-ca.crt"
            op          = "create"
          }]
        } : {}
        cluster = {
          # Single control plane must also schedule workloads
          allowSchedulingOnControlPlanes = var.control_plane_count == 1
          apiServer = {
            extraArgs = {
              "oidc-issuer-url"     = var.oidc_issuer_url
              "oidc-client-id"      = var.oidc_client_id
              "oidc-username-claim" = var.oidc_username_claim
              "oidc-ca-file"        = "/etc/kubernetes/oidc-ca.crt"
            }
            extraVolumes = var.root_ca != "" ? [{
              hostPath  = "/var/etc/kubernetes/oidc-ca.crt"
              mountPath = "/etc/kubernetes/oidc-ca.crt"
              readonly  = true
            }] : []
          }
        }
      })
    ],
    local.common_patches
  )
}

resource "talos_machine_configuration_apply" "controlplane" {
  for_each   = local.cp_nodes
  depends_on = [docker_container.node]

  lifecycle {
    replace_triggered_by = [terraform_data.cluster_parameters]
  }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  endpoint                    = each.value.ip
  node                        = each.value.ip
}

# ── Bootstrap ─────────────────────────────────────────────────────────────────

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  lifecycle {
    replace_triggered_by = [terraform_data.cluster_parameters]
  }

  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = local.bootstrap_ip
  node                 = local.bootstrap_ip
}

# Prevents bootstrap from re-running on subsequent applies
resource "terraform_data" "bootstrap_gate" {
  input = talos_machine_bootstrap.this.id

  lifecycle {
    replace_triggered_by = [terraform_data.cluster_parameters]
    ignore_changes       = [input]
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

  lifecycle {
    replace_triggered_by = [terraform_data.cluster_parameters]
  }

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

  lifecycle {
    replace_triggered_by = [terraform_data.cluster_parameters]
  }

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.bootstrap_ip
}

resource "local_file" "kubeconfig" {
  content         = yamlencode(local.kubeconfig_with_oidc)
  filename        = var.kubeconfig_path
  file_permission = "0600"

  lifecycle {
    replace_triggered_by = [terraform_data.cluster_parameters]
  }
}

resource "local_file" "automation_kubeconfig" {
  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = var.automation_kubeconfig_path
  file_permission = "0600"

  lifecycle {
    replace_triggered_by = [terraform_data.cluster_parameters]
  }
}

resource "local_file" "oidc_rbac" {
  content = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata   = { name = "oidc-${var.oidc_username}-view" }
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = "view"
    }
    subjects = [{
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "User"
      name     = "${var.oidc_issuer_url}#${var.oidc_username}"
    }]
  })
  filename        = "${var.automation_kubeconfig_path}.oidc-rbac.yaml"
  file_permission = "0600"

  depends_on = [local_file.automation_kubeconfig]
}

resource "terraform_data" "oidc_rbac" {
  triggers_replace = [
    local_file.oidc_rbac.content,
    local_file.automation_kubeconfig.content,
  ]

  provisioner "local-exec" {
    command = "kubectl --kubeconfig='${var.automation_kubeconfig_path}' apply --filename='${local_file.oidc_rbac.filename}'"
  }
}

# ── talosconfig ───────────────────────────────────────────────────────────────

locals {
  kubeconfig_with_oidc = merge(yamldecode(talos_cluster_kubeconfig.this.kubeconfig_raw), {
    users = concat(
      [
        for user in yamldecode(talos_cluster_kubeconfig.this.kubeconfig_raw).users : user
        if user.name != "oidc"
      ],
      [{
        name = "oidc"
        user = {
          exec = {
            apiVersion         = "client.authentication.k8s.io/v1"
            command            = "kubectl"
            installHint        = "Install kubelogin-oidc with Devbox."
            provideClusterInfo = true
            args = [
              "oidc-login",
              "get-token",
              "--oidc-issuer-url=${var.oidc_issuer_url}",
              "--oidc-client-id=${var.oidc_client_id}",
              "--oidc-pkce-method=S256",
            ]
          }
        }
      }]
    )
    contexts = [
      for context in yamldecode(talos_cluster_kubeconfig.this.kubeconfig_raw).contexts : merge(context, {
        context = merge(context.context, { user = "oidc" })
      })
    ]
  })

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

  lifecycle {
    replace_triggered_by = [terraform_data.cluster_parameters]
  }
}
