variable "name" {
  description = "Container/hostname identifier"
  type        = string
  default     = "kcp"
}

variable "data_dir" {
  description = "Local directory to write TLS material into"
  type        = string
}

variable "network_name" {
  description = "Docker network to attach to"
  type        = string
}

variable "ip_address" {
  description = "Static IP address within the Docker network"
  type        = string
}

variable "hostname" {
  description = "Public hostname kcp is reached at (e.g. kcp.home.lab) — used for its shard URLs"
  type        = string
}

variable "kubeconfig_path" {
  description = "Absolute path to write kcp's generated admin.kubeconfig"
  type        = string
}

variable "port" {
  description = "Secure port kcp listens on (TLS terminated by kcp itself, passed through by HAProxy)"
  type        = number
  default     = 6443
}

variable "tls_cert" {
  description = "PEM certificate for kcp's own TLS termination"
  type        = string
}

variable "tls_key" {
  description = "PEM private key matching tls_cert"
  type        = string
  sensitive   = true
}

variable "root_ca" {
  description = "PEM root CA appended after tls_cert to form the full chain"
  type        = string
  default     = ""
}

variable "image" {
  description = "kcp image repository"
  type        = string
  default     = "ghcr.io/kcp-dev/kcp"
}

variable "tag" {
  description = "kcp image tag"
  type        = string
  default     = "v0.32.3"
}

variable "oidc" {
  description = "Optional OIDC configuration for kcp authentication"
  type = object({
    issuer_url     = string
    client_id      = string
    username_claim = string
    groups_claim   = string
    ca_cert        = optional(string)
  })
  default = null
}
