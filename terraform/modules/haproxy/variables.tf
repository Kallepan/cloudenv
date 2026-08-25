variable "name" {
  description = "Identifier used in container/config file names"
  type        = string
  default     = "cloudenv"
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
}

variable "kcp" {
  type = object({
    domain       = string
    ipv4_address = string
    port         = number
  })
  default = null
}

variable "dex" {
  type = object({
    port         = number
    ipv4_address = string
  })
  default = null
}

variable "openbao" {
  type = object({
    port         = number
    ipv4_address = string
  })
  default = null
}
