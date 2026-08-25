no-resolv
log-queries
log-facility=-

%{ for dns in upstream_dns ~}
server=${dns}
%{ endfor ~}

# Wildcard: *.${domain} → ${resolve_to} (haproxy)
address=/.${domain}/${resolve_to}

%{ for host, ip in extra_hosts ~}
address=/${host}/${ip}
%{ endfor ~}
