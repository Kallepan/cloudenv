locals {
  command = var.git_url != "" ? join(" \\\n    ", [
    "flux bootstrap git",
    "--url=${var.git_url}",
    "--branch=${var.git_branch}",
    "--path=${var.git_path}",
  ]) : "flux install --namespace=flux-system"

  # Recompute whenever any manifest file's content changes
  manifest_files = var.git_url == "" ? fileset(var.manifests_path, "**") : []
  manifests_hash = var.git_url == "" ? sha1(join("", [
    for f in local.manifest_files : filesha1("${var.manifests_path}/${f}")
  ])) : ""

  # source-controller only trusts this registry when certSecretRef points at our CA
  ocirepo_manifest = yamlencode({
    apiVersion = "source.toolkit.fluxcd.io/v1"
    kind       = "OCIRepository"
    metadata   = { name = var.oci_repo_name, namespace = "flux-system" }
    spec = merge(
      {
        interval = "1m"
        url      = "oci://${var.registry_domain}/${var.oci_repo_name}"
        ref      = { tag = var.oci_tag }
      },
      var.root_ca != "" ? { certSecretRef = { name = "${var.oci_repo_name}-ca" } } : {}
    )
  })

  kustomization_manifest = yamlencode({
    apiVersion = "kustomize.toolkit.fluxcd.io/v1"
    kind       = "Kustomization"
    metadata   = { name = "apps", namespace = "flux-system" }
    spec = {
      interval  = "5m"
      prune     = true
      sourceRef = { kind = "OCIRepository", name = var.oci_repo_name }
      path      = "./${var.app_path}"
    }
  })
}

resource "terraform_data" "install" {
  triggers_replace = [
    var.kubeconfig_raw,
    var.git_url,
    var.git_branch,
    var.git_path,
  ]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = local.command
  }
}

resource "local_file" "sync_manifests" {
  count           = var.git_url == "" ? 1 : 0
  content         = "${local.ocirepo_manifest}---\n${local.kustomization_manifest}"
  filename        = "/tmp/flux-${var.oci_repo_name}-sync.yaml"
  file_permission = "0644"
}

resource "local_file" "ca_cert" {
  count           = var.git_url == "" && var.root_ca != "" ? 1 : 0
  content         = var.root_ca
  filename        = "/tmp/flux-${var.oci_repo_name}-ca.pem"
  file_permission = "0644"
}

# Git-less GitOps: push local manifests to the in-cluster OCI registry and let
# Flux reconcile from there via an OCIRepository + Kustomization pair.
resource "terraform_data" "sync" {
  count      = var.git_url == "" ? 1 : 0
  depends_on = [terraform_data.install, local_file.sync_manifests, local_file.ca_cert]

  triggers_replace = [
    local.manifests_hash,
    var.oci_repo_name,
    var.oci_tag,
    var.app_path,
    var.root_ca,
  ]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = <<-EOT
      set -euo pipefail
      flux push artifact "oci://${var.registry_domain}/${var.oci_repo_name}:${var.oci_tag}" \
        --path="${var.manifests_path}" \
        --source="local://terraform" \
        --revision="terraform@sha1:${local.manifests_hash}"

      %{ if var.root_ca != "" ~}
      kubectl -n flux-system create secret generic ${var.oci_repo_name}-ca \
        --from-file=ca.crt=${local_file.ca_cert[0].filename} \
        --dry-run=client -o yaml | kubectl apply -f -
      %{ endif ~}
      kubectl apply -f ${local_file.sync_manifests[0].filename}
    EOT
  }
}

