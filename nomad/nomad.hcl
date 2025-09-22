# Nomad configuration template for HashiStack demo

datacenter = "dc1"
data_dir = "/opt/hashicorp/data/nomad"
log_level = "INFO"

# Server configuration
server {
  enabled = true
  bootstrap_expect = 3

  # Server join configuration
  server_join {
    retry_join = ["{{ range service \"nomad\" }}{{ .Address }}:4648{{ end }}"]
    retry_max = 3
    retry_interval = "15s"
  }
}

# Client configuration
client {
  enabled = true

  # Server addresses for clients
  servers = ["{{ range service \"nomad\" }}{{ .Address }}:4647{{ end }}"]

  # Client options
  options = {
    "driver.allowlist" = "docker,exec,raw_exec"
    "docker.cleanup.image" = "false"
    "docker.cleanup.image.delay" = "1h"
  }

  # Host volumes
  host_volume "webapp-data" {
    path      = "/opt/webapp/data"
    read_only = false
  }
}

# Network configuration
bind_addr = "{{ GetInterfaceIP \"eth0\" }}"

# Consul integration
consul {
  address = "{{ GetInterfaceIP \"eth0\" }}:8500"

  # Service registration
  server_service_name = "nomad"
  client_service_name = "nomad-client"
  auto_advertise      = true

  # Server discovery
  server_auto_join = true
  client_auto_join = true
}

# Vault integration
vault {
  enabled = true
  address = "http://{{ GetInterfaceIP \"eth0\" }}:8200"

  # Task token settings
  task_token_ttl = "1h"
  create_from_role = "nomad-cluster"

  # CA and token settings (use environment variables)
  # ca_file = "/etc/hashicorp/vault/vault-ca.pem"
  # token = "will be set via environment variable"
}

# UI configuration
ui {
  enabled = true

  consul {
    ui_url = "http://{{ GetInterfaceIP \"eth0\" }}:8500/ui"
  }

  vault {
    ui_url = "http://{{ GetInterfaceIP \"eth0\" }}:8200/ui"
  }
}

# ACL configuration (disabled for demo)
acl {
  enabled = false
}

# Telemetry
telemetry {
  collection_interval = "10s"
  disable_hostname = false
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}

# Plugin configuration
plugin "docker" {
  config {
    allow_privileged = false
    allow_caps = ["audit_write", "chown", "dac_override", "fowner", "fsetid", "kill", "mknod", "net_bind_service", "setfcap", "setgid", "setpcap", "setuid", "sys_chroot"]

    # Garbage collection
    gc {
      image       = true
      image_delay = "3m"
      container   = true
    }

    # Volume options
    volumes {
      enabled = true
    }
  }
}