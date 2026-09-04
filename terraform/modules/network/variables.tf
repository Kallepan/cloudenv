variable "name" {
  description = "Docker network name"
  type        = string
}

variable "subnet" {
  description = "Network CIDR"
  type        = string
  default     = "10.250.0.0/24"
}

variable "gateway" {
  description = "Network gateway"
  type        = string
  default     = "10.250.0.1"
}
