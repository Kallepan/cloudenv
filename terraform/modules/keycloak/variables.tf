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
}

variable "data_dir" {
  description = "Directory for generated Keycloak configuration"
  type        = string
}

variable "oidc_realm" {
  description = "Realm provisioned for Kubernetes OIDC authentication"
  type        = string
  default     = "cloudenv"
}

variable "oidc_client_id" {
  description = "OIDC client ID provisioned for Kubernetes"
  type        = string
  default     = "kubernetes"
}

variable "oidc_username" {
  description = "Initial OIDC user"
  type        = string
  default     = "admin"
}

variable "oidc_password" {
  description = "Initial OIDC user password"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "oidc_first_name" {
  description = "Initial OIDC user's first name"
  type        = string
  default     = "Admin"
}

variable "oidc_last_name" {
  description = "Initial OIDC user's last name"
  type        = string
  default     = "Admin"
}

variable "oidc_user_email" {
  description = "Initial OIDC user's email address"
  type        = string
  default     = "admin@home.lab"
}
