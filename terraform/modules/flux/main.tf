locals {
  command = var.git_url != "" ? join(" \\\n    ", [
    "flux bootstrap git",
    "--url=${var.git_url}",
    "--branch=${var.git_branch}",
    "--path=${var.git_path}",
  ]) : "flux install --namespace=flux-system"
}

resource "terraform_data" "this" {
  triggers_replace = [
    var.kubeconfig_raw,
    var.git_url,
    var.git_branch,
    var.git_path,
  ]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = local.command
  }
}
