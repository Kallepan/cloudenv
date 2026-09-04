variable "name" {
  description = "Identifier used in container/config file names"
  type        = string
  default     = "cloudenv"
}

variable "tag" {
  description = "HAProxy image tag"
  type        = string
}

variable "data_dir" {
  description = "Local directory to write rendered config/TLS material into"
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

variable "clusters" {
  description = "Cluster backends to configure"
  type = list(object({
    name        = string
    base_domain = string
    api_domain  = string
    controlplanes = list(object({
      node_name    = string
      ipv4_address = string
    }))
    workers = list(object({
      node_name    = string
      ipv4_address = string
    }))
    ports = object({
      k8s   = number
      http  = number
      https = number
    })
  }))

  validation {
    condition     = length(var.clusters) == length(distinct([for c in var.clusters : c.name]))
    error_message = "Each entry in clusters must have a unique \"name\" — it's used as the HAProxy backend identifier."
  }
}

variable "registries" {
  description = "Registry backends to configure"
  type = list(object({
    name         = string
    domain       = string
    ipv4_address = string
    port         = number
  }))
  default = []

  validation {
    condition     = length(var.registries) == length(distinct([for r in var.registries : r.name]))
    error_message = "Each entry in registries must have a unique \"name\" — it's used as the HAProxy backend identifier."
  }
}

variable "openbao" {
  type = object({
    domain       = string
    port         = number
    ipv4_address = string
  })
  default = null
}

variable "keycloak" {
  type = object({
    domain       = string
    port         = number
    ipv4_address = string
  })
  default = null
}

variable "kcp" {
  type = object({
    domain       = string
    port         = number
    ipv4_address = string
  })
  default = null
}

variable "seaweedfs" {
  description = "SeaweedFS master web UI backend — TLS terminated locally, like openbao/keycloak"
  type = object({
    domain       = string
    port         = number
    ipv4_address = string
  })
  default = null
}

variable "tls_cert" {
  description = "PEM certificate used to terminate TLS for dedicated frontends (e.g. openbao)"
  type        = string
  default     = ""
}

variable "tls_key" {
  description = "PEM private key matching tls_cert"
  type        = string
  default     = ""
  sensitive   = true
}
