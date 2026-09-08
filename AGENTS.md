# Codex instructions

## Development environment

Use the repository's Devbox environment for project commands. Prefer running
commands through `devbox run -- <command>`; for an interactive session, use
`devbox shell` first. This ensures the pinned versions of tools such as
OpenTofu and `just` are used.

## Hard reset

Treat a hard reset as destructive. Before running it, tell the user that it
will delete the CloudEnv Docker containers, Docker network, and local
OpenTofu/Terraform state, and ask for explicit confirmation.

The default cluster name is `cloudenv`; if `terraform/local.tfvars` overrides
`cluster_name`, use that value instead. After confirmation, run the following
from the repository root:

```sh
devbox run -- just hard-reset [cluster_name]
```

The recipe requires typing `HARD RESET` and safely skips Docker cleanup when
the target network does not exist.

Do not use an unscoped command such as `docker rm -f $(docker ps -aq)` or
`docker system prune`: those can delete containers and resources unrelated to
this repository.
