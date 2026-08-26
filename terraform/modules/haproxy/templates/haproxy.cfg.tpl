global
	stats socket /tmp/haproxy-api.sock user haproxy group haproxy mode 660 level admin expose-fd listeners
	log stdout format raw local0 debug

	# Used in docker healthcheck
	stats socket /tmp/haproxy.stat mode 660 level admin expose-fd listeners
	stats timeout 30s

defaults
	mode http
	timeout client 10s
	timeout connect 5s
	timeout server 10s
	timeout http-request 10s
	log global

frontend stats
	bind *:8404
	mode http
	stats enable
	stats uri /
	stats refresh 10s

frontend http-in
	bind *:80
	option httplog
	option forwardfor

%{ for registry in registries ~}
	# Registry Config for ${registry.name}
	use_backend ${registry.name}_http if { hdr(host) -i ${registry.domain} }
%{ endfor ~}

%{ for cluster in clusters ~}
	# Backend Config for ${cluster.name}
	use_backend ${cluster.name}_http if { hdr(host) -m end .${cluster.base_domain} }
%{ endfor ~}

	use_backend health_check if { path /healthz }

	default_backend no-match

frontend https-tls-passthrough
	bind *:443
	mode tcp
	option tcplog

	# Wait for a client hello for at most 5 seconds
	tcp-request inspect-delay 5s
	tcp-request content accept if { req_ssl_hello_type 1 }

%{ for registry in registries ~}
	# Registry Config for ${registry.name}
	use_backend ${registry.name}_https if { req_ssl_sni -i ${registry.domain} }
%{ endfor ~}

%{ if openbao != null ~}
	# OpenBao (TLS terminated locally on 127.0.0.1, then proxied to the HTTP backend)
	use_backend openbao_terminate if { req_ssl_sni -i ${openbao.domain} }
%{ endif ~}

%{ if keycloak != null ~}
	# Keycloak (TLS terminated locally on 127.0.0.1, then proxied to the HTTP backend)
	use_backend keycloak_terminate if { req_ssl_sni -i ${keycloak.domain} }
%{ endif ~}

%{ if seaweedfs != null ~}
	# SeaweedFS master UI (TLS terminated locally, then proxied to the HTTP backend)
	use_backend seaweedfs_terminate if { req_ssl_sni -i ${seaweedfs.domain} }
%{ endif ~}

%{ if kcp != null ~}
	# kcp (TLS passthrough — kcp terminates its own TLS)
	use_backend kcp_k8s_api if { req_ssl_sni -i ${kcp.domain} }
%{ endif ~}

%{ for cluster in clusters ~}
	# Backend Config for ${cluster.name}
	use_backend ${cluster.name}_https if { req_ssl_sni -m end .${cluster.base_domain} }
%{ endfor ~}

	default_backend no-match

frontend https-k8s
	bind *:6443
	mode tcp
	option tcplog

	# Wait for a client hello for at most 5 seconds
	tcp-request inspect-delay 5s
	tcp-request content accept if { req_ssl_hello_type 1 }

%{ for cluster in clusters ~}
	# Backend Config for ${cluster.name}
	use_backend ${cluster.name}_k8s_api if { req_ssl_sni -i ${cluster.api_domain} }
%{ endfor ~}

%{ if kcp != null ~}
	# kcp API backend (TLS passthrough — kcp terminates its own TLS)
	use_backend kcp_k8s_api if { req_ssl_sni -i ${kcp.domain} }
%{ endif ~}

	default_backend no-match

backend no-match
	mode http
	http-request deny deny_status 400

%{ for cluster in clusters ~}
# Kubernetes API backend - ${cluster.name}
backend ${cluster.name}_k8s_api
	mode tcp

%{ for node in cluster.controlplanes ~}
	server ${node.node_name} ${node.ipv4_address}:${cluster.ports.k8s} check
%{ endfor ~}

# HTTP backend - ${cluster.name}
backend ${cluster.name}_http
%{ for node in cluster.controlplanes ~}
	server ${node.node_name} ${node.ipv4_address}:${cluster.ports.http} check
%{ endfor ~}
%{ for node in cluster.workers ~}
	server ${node.node_name} ${node.ipv4_address}:${cluster.ports.http} check
%{ endfor ~}

# HTTPS backend - ${cluster.name}
backend ${cluster.name}_https
	mode tcp
%{ for node in cluster.controlplanes ~}
	server ${node.node_name} ${node.ipv4_address}:${cluster.ports.https} check
%{ endfor ~}
%{ for node in cluster.workers ~}
	server ${node.node_name} ${node.ipv4_address}:${cluster.ports.https} check
%{ endfor ~}
%{ endfor ~}

%{ if kcp != null ~}
# kcp API backend (TLS passthrough — kcp terminates its own TLS)
backend kcp_k8s_api
	mode tcp
	server kcp ${kcp.ipv4_address}:${kcp.port} check
%{ endif ~}

%{ if openbao != null ~}
# OpenBao HTTP backend
backend openbao_http
	mode http
	server openbao ${openbao.ipv4_address}:${openbao.port} check

# Loopback TCP hop into the local TLS-termination frontend below
backend openbao_terminate
	mode tcp
	server openbao_local 127.0.0.1:8443 send-proxy-v2
%{ endif ~}

%{ if keycloak != null ~}
# Keycloak HTTP backend
backend keycloak_http
	mode http
	server keycloak ${keycloak.ipv4_address}:${keycloak.port} check

# Loopback TCP hop into the local TLS-termination frontend below
backend keycloak_terminate
	mode tcp
	server keycloak_local 127.0.0.1:8444 send-proxy-v2
%{ endif ~}

%{ if seaweedfs != null ~}
# SeaweedFS master UI HTTP backend
backend seaweedfs_http
	mode http
	server seaweedfs ${seaweedfs.ipv4_address}:${seaweedfs.port} check

# Loopback TCP hop into the local TLS-termination frontend below
backend seaweedfs_terminate
	mode tcp
	server seaweedfs_local 127.0.0.1:8445 send-proxy-v2
%{ endif ~}

%{ for registry in registries ~}
# Registry backend - ${registry.name}
backend ${registry.name}_http
	server ${registry.name} ${registry.ipv4_address}:${registry.port} check
%{ endfor ~}

%{ for registry in registries ~}
# Registry backend - ${registry.name}
backend ${registry.name}_https
	mode tcp
	server ${registry.name} ${registry.ipv4_address}:${registry.port} check
%{ endfor }

backend health_check
    mode http
    http-request return status 200 content-type application/json string '{"status":"OK"}'

%{ if openbao != null && tls_cert_path != null ~}
# TLS termination for OpenBao, reached via the openbao_terminate backend above
frontend openbao_https
	bind 127.0.0.1:8443 ssl crt ${tls_cert_path} accept-proxy
	mode http
	option httplog
	default_backend openbao_http
%{ endif ~}

%{ if keycloak != null && tls_cert_path != null ~}
# TLS termination for Keycloak, reached via the keycloak_terminate backend above
frontend keycloak_https
	bind 127.0.0.1:8444 ssl crt ${tls_cert_path} accept-proxy
	mode http
	option httplog
	http-request set-header X-Forwarded-Proto https
	default_backend keycloak_http
%{ endif ~}

%{ if seaweedfs != null && tls_cert_path != null ~}
# TLS termination for SeaweedFS master UI, reached via the seaweedfs_terminate backend above
frontend seaweedfs_https
	bind 127.0.0.1:8445 ssl crt ${tls_cert_path} accept-proxy
	mode http
	option httplog
	default_backend seaweedfs_http
%{ endif ~}
