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

variable "network_prefix" {
  description = "IPv4 /24 prefix for the Docker network (e.g. \"10.250.0\"); choose one that does not overlap VPN routes"
  type        = string
  default     = "10.250.0"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){2}[0-9]{1,3}$", var.network_prefix))
    error_message = "network_prefix must be an IPv4 prefix in the form \"A.B.C\" (no trailing dot, no CIDR suffix)."
  }
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

variable "oidc_realm" {
  description = "Keycloak realm used for Kubernetes OIDC authentication"
  type        = string
  default     = "cloudenv"
}

variable "oidc_client_id" {
  description = "Keycloak OIDC client ID for Kubernetes"
  type        = string
  default     = "kubernetes"
}

variable "oidc_username" {
  description = "Initial Keycloak OIDC username"
  type        = string
  default     = "admin"
}

variable "oidc_user_password" {
  description = "Initial Keycloak OIDC user password"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "oidc_first_name" {
  description = "Initial Keycloak OIDC user's first name"
  type        = string
  default     = "Admin"
}

variable "oidc_last_name" {
  description = "Initial Keycloak OIDC user's last name"
  type        = string
  default     = "Admin"
}

variable "oidc_user_email" {
  description = "Initial Keycloak OIDC user's email address"
  type        = string
  default     = "admin@home.lab"
}

variable "haproxy_image_tag" {
  description = "HAProxy Docker image tag"
  type        = string
  default     = "lts"
}

variable "dnsmasq_image_tag" {
  description = "dnsmasq Docker image tag"
  type        = string
  default     = "latest"
}

variable "zot_image_tag" {
  description = "zot Docker image tag"
  type        = string
  default     = "latest"
}

variable "openbao_image_tag" {
  description = "OpenBao Docker image tag"
  type        = string
  default     = "latest"
}

variable "keycloak_image_tag" {
  description = "Keycloak Docker image tag"
  type        = string
  default     = "latest"
}

variable "kcp_image_tag" {
  description = "kcp Docker image tag"
  type        = string
  default     = "v0.32.3"
}

variable "seaweedfs_image_tag" {
  description = "SeaweedFS Docker image tag"
  type        = string
  default     = "latest"
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

variable "openbao_root_token" {
  description = "Fixed root token for the local OpenBao dev-mode server"
  type        = string
  default     = "root"
  sensitive   = true
}

variable "keycloak_admin_password" {
  description = "Bootstrap admin password for the local Keycloak dev-mode server"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "seaweedfs_s3_access_key" {
  description = "Static S3 access key for the local SeaweedFS server"
  type        = string
  default     = "seaweedfs"
}

variable "seaweedfs_s3_secret_key" {
  description = "Static S3 secret key for the local SeaweedFS server"
  type        = string
  default     = "seaweedfs-secret"
  sensitive   = true
}
