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
