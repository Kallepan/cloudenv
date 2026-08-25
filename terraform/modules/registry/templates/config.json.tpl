{
  "distSpecVersion": "1.1.0",
  "storage": {
    "rootDirectory": "/var/lib/registry",
    "dedupe": true,
    "gc": false
  },
  "http": {
    "address": "0.0.0.0",
    "port": "${port}",
    "compat": ["docker2s2"],
    "tls": {
      "cert": "/etc/docker/registry/cert.pem",
      "key": "/etc/docker/registry/cert.key"
    }
  },
  "log": {
    "level": "info"
  },
  "extensions": {
    "ui": {
      "enable": true
    },
    "search": {
      "enable": true
    }%{ if mirror },
    "sync": {
      "enable": true,
      "credentialsFile": "/etc/zot/sync-creds.json",
      "registries": [
        {
          "urls": ["https://registry.k8s.io"],
          "onDemand": true,
          "maxRetries": 3,
          "retryDelay": "30s",
          "content": [
            {
              "prefix": "**",
              "destination": "/k8s"
            }
          ]
        },
        {
          "urls": ["https://index.docker.io"],
          "onDemand": true,
          "maxRetries": 3,
          "retryDelay": "30s",
          "content": [
            {
              "prefix": "**",
              "destination": "/docker"
            }
          ]
        },
        {
          "urls": ["https://ghcr.io"],
          "onDemand": true,
          "maxRetries": 3,
          "retryDelay": "30s",
          "content": [
            {
              "prefix": "**",
              "destination": "/ghcr"
            }
          ]
        },
        {
          "urls": ["https://quay.io"],
          "onDemand": true,
          "maxRetries": 3,
          "retryDelay": "30s",
          "content": [
            {
              "prefix": "**",
              "destination": "/quay"
            }
          ]
        }%{ if length(sync_prefill) > 0 }%{ for group in [for registry, entries in { for e in sync_prefill : e.registry => e... } : { registry = registry, entries = entries }] },
        {
          "urls": ["https://${group.registry}"],
          "onDemand": true,
          "pollInterval": "24h",
          "maxRetries": 3,
          "retryDelay": "30s",
          "content": [%{ for i, e in group.entries }
            {
              "prefix": "${join("/", slice(split("/", e.prefix), 1, length(split("/", e.prefix))))}",
              "destination": "/${split("/", e.prefix)[0]}",
              "tags": { "regex": "^${replace(e.tag, ".", "\\\\.")}$" }
            }%{ if i < length(group.entries) - 1 },%{ endif }%{ endfor }]
        }%{ endfor }%{ endif }

      ]
    }%{ endif }
  }
}
