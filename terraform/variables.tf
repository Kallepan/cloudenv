variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
  default     = "cloudenv"
}

variable "domain" {
  description = "Base domain for ingress (e.g. home.lab)"
  type        = string
  default     = "home.lab"
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 1
}

variable "talos_version" {
  description = "Talos version (e.g. v1.9.0)"
  type        = string
  default     = "v1.9.0"
}

variable "kubernetes_version" {
  description = "Kubernetes version (e.g. 1.32.0)"
  type        = string
  default     = "1.32.0"
}

variable "enable_flux" {
  description = "Install Flux into the cluster after creation"
  type        = bool
  default     = true
}

variable "flux_git_url" {
  description = "Git URL for Flux bootstrap — if empty, runs 'flux install' instead"
  type        = string
  default     = ""
}

variable "flux_git_branch" {
  description = "Git branch for Flux bootstrap"
  type        = string
  default     = "main"
}

variable "flux_git_path" {
  description = "Path in the git repo where Flux manifests live"
  type        = string
  default     = "manifests/base"
}
