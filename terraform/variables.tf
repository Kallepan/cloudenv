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
  description = "IPv4 /24 prefix for the Docker network; choose one that does not overlap VPN routes"
  type        = string
  default     = "10.250.0"
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
