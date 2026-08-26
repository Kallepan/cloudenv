variable "domain" {
  description = "Base domain for certificate generation (e.g. home.lab)"
  type        = string
}

variable "data_dir" {
  description = "Local directory to write generated certificates into"
  type        = string
}
