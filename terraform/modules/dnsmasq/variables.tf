variable "name" {
  description = "Identifier used for the container name (e.g. \"<name>-dnsmasq\")"
  type        = string
  default     = "dnsmasq"
}

variable "network_name" {
  description = "Docker network to attach to"
  type        = string
}

variable "ip_address" {
  description = "Static IP address within the Docker network"
  type        = string
}

variable "domain" {
  description = "Base domain to resolve (e.g. home.lab)"
  type        = string
}

variable "resolve_to" {
  description = "IP address that *.domain resolves to (haproxy)"
  type        = string
}

variable "upstream_dns" {
  description = "Upstream DNS servers for non-local queries"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "extra_hosts" {
  description = "Additional host → IP mappings"
  type        = map(string)
  default     = {}
}
