variable "name" {
  description = "Container/hostname identifier"
  type        = string
  default     = "keycloak"
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
  description = "Port Keycloak listens on (dev-mode HTTP, no TLS)"
  type        = number
  default     = 8080
}

variable "hostname" {
  description = "Public hostname Keycloak is reached at (used for KC_HOSTNAME so it emits https:// URLs)"
  type        = string
}

variable "admin_user" {
  description = "Bootstrap admin username for the dev-mode server"
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Bootstrap admin password for the dev-mode server"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "image" {
  description = "Keycloak image repository"
  type        = string
  default     = "quay.io/keycloak/keycloak"
}

variable "tag" {
  description = "Keycloak image tag"
  type        = string
  default     = "latest"
}
