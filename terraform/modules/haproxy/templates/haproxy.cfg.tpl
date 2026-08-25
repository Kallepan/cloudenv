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

%{ for cluster in clusters ~}
	# Backend Config for ${cluster.name}
	use_backend ${cluster.name}_https if { req_ssl_sni -m end .${cluster.base_domain} }
%{ endfor ~}

%{ if kcp != null ~}
	# KCP API backend (TLS passthrough on 443)
	use_backend kcp_k8s_api if { req_ssl_sni -i ${kcp.domain} }
%{ endif ~}

	default_backend no-match

%{ if openbao != null ~}
frontend openbao
	bind *:${openbao.port}
	mode http
	option httplog
	default_backend openbao_http

%{ endif ~}
%{ if dex != null ~}
frontend dex
	bind *:${dex.port}
	mode tcp
	option tcplog
	default_backend dex_tcp

%{ endif ~}
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
	# KCP API backend
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
# Kubernetes API backend - kcp
backend kcp_k8s_api
	mode tcp
	server kcp ${kcp.ipv4_address}:${kcp.port} check
%{ endif ~}

%{ if openbao != null ~}
# OpenBao HTTP backend
backend openbao_http
	mode http
	server openbao ${openbao.ipv4_address}:${openbao.port} check
%{ endif ~}

%{ if dex != null ~}
# Dex OIDC TCP passthrough backend
backend dex_tcp
	mode tcp
	server dex ${dex.ipv4_address}:${dex.port} check
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
