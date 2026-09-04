variable "name" {
  description = "Container/hostname identifier"
  type        = string
  default     = "seaweedfs"
}

variable "network_name" {
  description = "Docker network to attach to"
  type        = string
}

variable "ip_address" {
  description = "Static IP address within the Docker network"
  type        = string
}

variable "data_dir" {
  description = "Local directory to write rendered config into"
  type        = string
}

variable "hostname" {
  description = "Public hostname the master web UI is reached at (e.g. s3.home.lab)"
  type        = string
}

variable "master_port" {
  description = "Master server port — serves the admin web UI"
  type        = number
  default     = 9333
}

variable "volume_port" {
  description = "Volume server port"
  type        = number
  default     = 8080
}

variable "filer_port" {
  description = "Filer server port"
  type        = number
  default     = 8888
}

variable "s3_port" {
  description = "S3 API port"
  type        = number
  default     = 8333
}

variable "s3_access_key" {
  description = "Static S3 access key for local dev use"
  type        = string
  default     = "seaweedfs"
}

variable "s3_secret_key" {
  description = "Static S3 secret key for local dev use"
  type        = string
  default     = "seaweedfs-secret"
  sensitive   = true
}

variable "image" {
  description = "SeaweedFS image repository"
  type        = string
  default     = "chrislusf/seaweedfs"
}

variable "tag" {
  description = "SeaweedFS image tag"
  type        = string
}
