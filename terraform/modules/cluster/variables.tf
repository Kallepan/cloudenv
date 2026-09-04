variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
}

variable "network_name" {
  description = "Docker network name to attach nodes to"
  type        = string
}

variable "network_prefix" {
  description = "IPv4 /24 prefix for the Docker network (e.g. \"10.250.0\")"
  type        = string

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){2}[0-9]{1,3}$", var.network_prefix))
    error_message = "network_prefix must be an IPv4 prefix in the form \"A.B.C\" (no trailing dot, no CIDR suffix)."
  }
}
variable "kubeconfig_path" {
  description = "Absolute path to write the kubeconfig file"
  type        = string
}

variable "talosconfig_path" {
  description = "Absolute path to write the talosconfig file"
  type        = string
}

variable "domain" {
  description = "Base domain for ingress"
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

variable "root_ca" {
  description = "PEM root CA to inject into node trust stores via TrustedRootsConfig"
  type        = string
  default     = ""
}
