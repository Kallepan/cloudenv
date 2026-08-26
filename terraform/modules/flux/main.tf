locals {
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
    sha1(file("${path.module}/scripts/install.sh")),
  ]

  provisioner "local-exec" {
    command = "bash \"${path.module}/scripts/install.sh\""
    environment = {
      KUBECONFIG      = var.kubeconfig_path
      FLUX_GIT_URL    = var.git_url
      FLUX_GIT_BRANCH = var.git_branch
      FLUX_GIT_PATH   = var.git_path
    }
  }
}

resource "local_file" "sync_manifests" {
  count           = var.git_url == "" ? 1 : 0
  content         = "${local.ocirepo_manifest}---\n${local.kustomization_manifest}"
  filename        = "${var.data_dir}/flux-${var.oci_repo_name}-sync.yaml"
  file_permission = "0644"
}

resource "local_file" "ca_cert" {
  count           = var.git_url == "" && var.root_ca != "" ? 1 : 0
  content         = var.root_ca
  filename        = "${var.data_dir}/flux-${var.oci_repo_name}-ca.pem"
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
    sha1(file("${path.module}/scripts/sync.sh")),
  ]

  provisioner "local-exec" {
    command = "bash \"${path.module}/scripts/sync.sh\""
    environment = merge(
      {
        KUBECONFIG           = var.kubeconfig_path
        FLUX_MANIFESTS_PATH  = var.manifests_path
        FLUX_REGISTRY_DOMAIN = var.registry_domain
        FLUX_OCI_REPO_NAME   = var.oci_repo_name
        FLUX_OCI_TAG         = var.oci_tag
        FLUX_REVISION        = local.manifests_hash
        FLUX_SYNC_MANIFEST   = local_file.sync_manifests[0].filename
      },
      var.root_ca != "" ? { FLUX_CA_FILE = local_file.ca_cert[0].filename } : {}
    )
  }
}

