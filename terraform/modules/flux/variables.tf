variable "kubeconfig_path" {
  description = "Path to the cluster kubeconfig"
  type        = string
}

variable "kubeconfig_raw" {
  description = "Raw kubeconfig content — creates an implicit dependency on the cluster being ready"
  type        = string
  sensitive   = true
}

variable "git_url" {
  description = "Git URL for Flux bootstrap — empty runs 'flux install' only"
  type        = string
  default     = ""
}

variable "git_branch" {
  type    = string
  default = "main"
}

variable "git_path" {
  description = "Path in the git repo where Flux manifests live"
  type        = string
  default     = "manifests/base"
}

variable "registry_domain" {
  description = "FQDN of the local OCI registry used for git-less sync (ignored when git_url is set)"
  type        = string
  default     = ""
}

variable "manifests_path" {
  description = "Absolute path to the local manifests directory to push as an OCI artifact"
  type        = string
  default     = ""
}

variable "oci_repo_name" {
  description = "Name of the OCI repository the manifests are pushed to"
  type        = string
  default     = "cluster-manifests"
}

variable "oci_tag" {
  description = "Tag used for the pushed manifests artifact"
  type        = string
  default     = "latest"
}

variable "app_path" {
  description = "Path (relative to manifests_path) that the Flux Kustomization builds and applies"
  type        = string
  default     = "apps/podinfo"
}

variable "root_ca" {
  description = "PEM root CA the registry's TLS cert was issued from — trusted by source-controller via certSecretRef"
  type        = string
  default     = ""
}
