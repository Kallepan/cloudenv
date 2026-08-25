terraform {
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

locals {
  output_dir = abspath("${path.root}/../.certs")
}

data "external" "certs" {
  program = ["bash", "${path.module}/scripts/mkcert.sh"]

  query = {
    domain     = var.domain
    output_dir = local.output_dir
  }
}

# mkcert -CAROOT keeps the root CA outside the repo; mirror it here for visibility
resource "local_file" "root_ca" {
  content         = data.external.certs.result.root_ca
  filename        = "${local.output_dir}/rootCA.pem"
  file_permission = "0644"
}
