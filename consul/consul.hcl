# Consul configuration template for HashiStack demo

datacenter = "dc1"
data_dir = "/opt/hashicorp/data/consul"
log_level = "INFO"
server = true

# Bootstrap configuration - should match cluster size
bootstrap_expect = 3

# Network configuration
bind_addr = "{{ GetInterfaceIP \"eth0\" }}"
client_addr = "0.0.0.0"

# UI configuration
ui_config {
  enabled = true
}

# Service mesh configuration
connect {
  enabled = true
}

# DNS configuration
recursors = ["8.8.8.8", "8.8.4.4"]

# Performance tuning
performance {
  raft_multiplier = 1
}

# Logging
log_rotate_duration = "24h"
log_rotate_max_files = 3

# ACL configuration (disabled for demo)
acl = {
  enabled = false
  default_policy = "allow"
  enable_token_persistence = true
}

# Ports configuration
ports {
  grpc = 8502
}

# TLS configuration (disabled for demo)
# ca_file = "/etc/hashicorp/consul/consul-agent-ca.pem"
# cert_file = "/etc/hashicorp/consul/dc1-server-consul-0.pem"
# key_file = "/etc/hashicorp/consul/dc1-server-consul-0-key.pem"
# verify_incoming = true
# verify_outgoing = true
# verify_server_hostname = true