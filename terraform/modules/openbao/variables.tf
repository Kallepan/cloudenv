variable "name" {
  description = "Container/hostname identifier"
  type        = string
  default     = "openbao"
}

variable "network_name" {
  description = "Docker network to attach to"
  type        = string
}

variable "ip_address" {
  description = "Static IP address within the Docker network"
  type        = string
}

variable "port" {
  description = "Port OpenBao listens on (dev-mode HTTP, no TLS)"
  type        = number
  default     = 8200
}

variable "root_token" {
  description = "Fixed root token for the dev-mode server"
  type        = string
  default     = "root"
  sensitive   = true
}

variable "image" {
  description = "OpenBao image repository"
  type        = string
  default     = "openbao/openbao"
}

variable "tag" {
  description = "OpenBao image tag"
  type        = string
  default     = "latest"
}
