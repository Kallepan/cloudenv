variable "name" {
  description = "Registry identifier used as the HAProxy backend name (keep short/logical, not the container name)"
  type        = string
  default     = "registry"
}

variable "container_name" {
  description = "Docker container name; defaults to \"<name>-registry\" if unset"
  type        = string
  default     = null
}

variable "network_name" {
  description = "Docker network to attach to"
  type        = string
}

variable "ip_address" {
  description = "Static IP address within the Docker network"
  type        = string
}

variable "domain" {
  description = "FQDN the registry is served on (e.g. registry.home.lab)"
  type        = string
}

variable "port" {
  description = "Port the registry listens on inside the container"
  type        = number
  default     = 443
}

variable "tls_cert" {
  description = "PEM certificate"
  type        = string
}

variable "tls_key" {
  description = "PEM private key"
  type        = string
  sensitive   = true
}

variable "zot_version" {
  description = "zot image tag"
  type        = string
  default     = "latest"
}

variable "mirror" {
  description = "Enable pull-through sync/mirroring of registry.k8s.io, docker.io, ghcr.io and quay.io"
  type        = bool
  default     = false
}

variable "sync_prefill" {
  description = "Extra sync targets, grouped by registry host — each entry is an image prefix + tag regex to prefetch"
  type = list(object({
    registry = string
    prefix   = string
    tag      = string
  }))
  default = []
}
