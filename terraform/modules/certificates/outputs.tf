output "cert" {
  description = "PEM certificate (wildcard for the domain)"
  value       = data.external.certs.result.cert
}

output "key" {
  description = "PEM private key"
  value       = data.external.certs.result.key
  sensitive   = true
}

output "root_ca" {
  description = "mkcert root CA PEM — inject into Talos TrustedRootsConfig"
  value       = data.external.certs.result.root_ca
}
