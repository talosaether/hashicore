# Nomad job specification for web application demo
# This job demonstrates Vault integration and Consul service registration

job "webapp" {
  datacenters = ["dc1"]
  type = "service"

  # Job constraints
  constraint {
    attribute = "${attr.kernel.name}"
    value     = "linux"
  }

  # Update strategy
  update {
    max_parallel      = 1
    min_healthy_time  = "10s"
    healthy_deadline  = "3m"
    progress_deadline = "10m"
    auto_revert       = false
    canary            = 0
  }

  # Migrate strategy
  migrate {
    max_parallel     = 1
    health_check     = "checks"
    min_healthy_time = "10s"
    healthy_deadline = "5m"
  }

  group "webapp" {
    count = 2

    # Networking configuration
    network {
      port "http" {
        to = 80
      }
    }

    # Vault configuration for the group
    vault {
      policies = ["webapp-policy"]
      change_mode = "restart"
    }

    # Service registration with Consul
    service {
      name = "webapp"
      port = "http"
      tags = [
        "frontend",
        "web",
        "nginx",
        "demo"
      ]

      meta {
        version = "1.0.0"
        environment = "demo"
      }

      # Health checks
      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }

      check {
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }

      # Connect configuration for service mesh
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "postgres"
              local_bind_port  = 5432
            }
          }
        }
      }
    }

    # Restart policy
    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    # Ephemeral disk
    ephemeral_disk {
      size = 300
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx:alpine"
        ports = ["http"]

        # Mount custom nginx configuration
        mount {
          type     = "bind"
          target   = "/etc/nginx/nginx.conf"
          source   = "local/nginx.conf"
          readonly = true
        }

        # Mount web content
        mount {
          type     = "bind"
          target   = "/usr/share/nginx/html"
          source   = "local/html"
          readonly = true
        }
      }

      # Template for nginx configuration
      template {
        data = <<EOF
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;

    sendfile on;
    keepalive_timeout 65;

    server {
        listen 80;
        server_name localhost;

        location / {
            root /usr/share/nginx/html;
            index index.html;
        }

        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        # Proxy to database connection (example)
        location /api/db {
            proxy_pass http://127.0.0.1:5432;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
EOF
        destination = "local/nginx.conf"
        change_mode = "restart"
      }

      # Template for web content with Vault secrets
      template {
        data = <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>HashiStack Demo WebApp</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #007acc; padding-bottom: 10px; }
        .info { background: #e3f2fd; padding: 15px; border-radius: 4px; margin: 20px 0; }
        .secret { background: #fff3e0; padding: 15px; border-radius: 4px; margin: 20px 0; border-left: 4px solid #ff9800; }
        .status { background: #e8f5e8; padding: 15px; border-radius: 4px; margin: 20px 0; }
        code { background: #f0f0f0; padding: 2px 6px; border-radius: 3px; font-family: monospace; }
        ul { line-height: 1.6; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 HashiStack Demo Application</h1>

        <div class="info">
            <h3>Application Information</h3>
            <ul>
                <li><strong>Node:</strong> {{ env "node.unique.name" }}</li>
                <li><strong>Allocation:</strong> {{ env "NOMAD_ALLOC_ID" }}</li>
                <li><strong>Job:</strong> {{ env "NOMAD_JOB_NAME" }}</li>
                <li><strong>Group:</strong> {{ env "NOMAD_GROUP_NAME" }}</li>
                <li><strong>Task:</strong> {{ env "NOMAD_TASK_NAME" }}</li>
            </ul>
        </div>

        <div class="secret">
            <h3>🔐 Vault Secrets Integration</h3>
            <p>The following secrets are retrieved from Vault:</p>
            <ul>
                {{with secret "secret/data/apps/webapp"}}
                <li><strong>Database Password:</strong> <code>{{ .Data.data.db_password }}</code></li>
                <li><strong>API Key:</strong> <code>{{ .Data.data.api_key }}</code></li>
                <li><strong>Debug Mode:</strong> <code>{{ .Data.data.debug_mode }}</code></li>
                {{end}}
            </ul>
            {{with secret "secret/data/database/postgres"}}
            <p><strong>Database Connection:</strong></p>
            <ul>
                <li><strong>Host:</strong> <code>{{ .Data.data.host }}</code></li>
                <li><strong>Port:</strong> <code>{{ .Data.data.port }}</code></li>
                <li><strong>Database:</strong> <code>{{ .Data.data.database }}</code></li>
                <li><strong>Username:</strong> <code>{{ .Data.data.username }}</code></li>
            </ul>
            {{end}}
        </div>

        <div class="status">
            <h3>✅ Service Status</h3>
            <p>This application is:</p>
            <ul>
                <li>✅ Deployed via <strong>Nomad</strong></li>
                <li>✅ Registered with <strong>Consul</strong> for service discovery</li>
                <li>✅ Using secrets from <strong>Vault</strong></li>
                <li>✅ Running in <strong>Docker</strong> container</li>
            </ul>
        </div>

        <div class="info">
            <h3>🔗 Service Discovery</h3>
            <p>This service is discoverable via:</p>
            <ul>
                <li><strong>Consul DNS:</strong> <code>webapp.service.consul</code></li>
                <li><strong>Consul HTTP API:</strong> <code>/v1/catalog/service/webapp</code></li>
                <li><strong>Consul Connect:</strong> Service mesh enabled</li>
            </ul>
        </div>

        <div class="info">
            <h3>🛠 Management UIs</h3>
            <ul>
                <li><a href="http://{{ env "attr.unique.network.ip-address" }}:4646" target="_blank">Nomad UI</a></li>
                <li><a href="http://{{ env "attr.unique.network.ip-address" }}:8500" target="_blank">Consul UI</a></li>
                <li><a href="http://{{ env "attr.unique.network.ip-address" }}:8200" target="_blank">Vault UI</a></li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF
        destination = "local/html/index.html"
        change_mode = "restart"
      }

      # Resources
      resources {
        cpu    = 100
        memory = 128
      }

      # Environment variables
      env {
        ENVIRONMENT = "demo"
        LOG_LEVEL = "INFO"
      }
    }
  }
}