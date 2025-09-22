job "demo-webapp" {
  datacenters = ["dc1"]
  type = "service"

  group "webapp" {
    count = 1

    network {
      port "http" {}
    }

    service {
      name = "demo-webapp"
      port = "http"
      tags = ["demo", "webapp", "nginx"]

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx:alpine"
        ports = ["http"]

        mount {
          type     = "bind"
          target   = "/usr/share/nginx/html/index.html"
          source   = "local/index.html"
          readonly = true
        }
      }

      template {
        data = <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>HashiStack Demo - Dev Environment</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 40px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: rgba(255,255,255,0.1);
            padding: 20px;
            border-radius: 15px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(0,0,0,0.3);
        }
        h1 {
            color: #fff;
            text-align: center;
            margin-bottom: 30px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.5);
        }
        .info {
            background: rgba(255,255,255,0.2);
            padding: 15px;
            border-radius: 8px;
            margin: 20px 0;
            border-left: 4px solid #4CAF50;
        }
        .services {
            background: rgba(255,255,255,0.2);
            padding: 15px;
            border-radius: 8px;
            margin: 20px 0;
            border-left: 4px solid #2196F3;
        }
        code {
            background: rgba(0,0,0,0.3);
            padding: 2px 6px;
            border-radius: 3px;
            font-family: monospace;
        }
        ul { line-height: 1.8; }
        .status {
            text-align: center;
            font-size: 18px;
            margin: 30px 0;
        }
        .emoji { font-size: 24px; }
    </style>
</head>
<body>
    <div class="container">
        <h1><span class="emoji">🚀</span> HashiStack Development Environment</h1>

        <div class="status">
            <p><strong>Status:</strong> <span style="color: #4CAF50;">✅ RUNNING</span></p>
            <p>Deployed via <strong>Nomad</strong> | Served by <strong>Nginx</strong></p>
        </div>

        <div class="info">
            <h3>🎯 Nomad Deployment Info</h3>
            <ul>
                <li><strong>Job:</strong> {{ env "NOMAD_JOB_NAME" }}</li>
                <li><strong>Task:</strong> {{ env "NOMAD_TASK_NAME" }}</li>
                <li><strong>Allocation:</strong> {{ env "NOMAD_ALLOC_ID" }}</li>
                <li><strong>Node:</strong> {{ env "node.unique.name" }}</li>
            </ul>
        </div>

        <div class="services">
            <h3>🌐 Service Discovery</h3>
            <p>This application is registered with Consul and discoverable via:</p>
            <ul>
                <li><strong>Service Name:</strong> <code>demo-webapp</code></li>
                <li><strong>Health Checks:</strong> HTTP endpoint monitoring</li>
                <li><strong>Tags:</strong> demo, webapp, nginx</li>
            </ul>
        </div>

        <div class="info">
            <h3>🛠 Management Interfaces</h3>
            <ul>
                <li><a href="http://localhost:4646" target="_blank" style="color: #FFD700;">Nomad UI</a> - Workload orchestration</li>
                <li><a href="http://localhost:8500" target="_blank" style="color: #FFD700;">Consul UI</a> - Service discovery</li>
                <li><a href="http://localhost:8200" target="_blank" style="color: #FFD700;">Vault UI</a> - Secrets management</li>
            </ul>
        </div>

        <div class="services">
            <h3>✨ HashiStack Integration</h3>
            <ul>
                <li>🎯 <strong>Nomad:</strong> Container orchestration and job scheduling</li>
                <li>🔗 <strong>Consul:</strong> Service registration and health monitoring</li>
                <li>🔐 <strong>Vault:</strong> Secrets management (available for templates)</li>
                <li>🐳 <strong>Docker:</strong> Container runtime</li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF
        destination = "local/index.html"
        change_mode = "restart"
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }
  }
}