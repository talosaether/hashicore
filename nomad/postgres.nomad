# Nomad job specification for PostgreSQL database demo
# This job demonstrates service registration with Consul

job "postgres" {
  datacenters = ["dc1"]
  type = "service"

  # Job constraints
  constraint {
    attribute = "${attr.kernel.name}"
    value     = "linux"
  }

  group "database" {
    count = 1

    # Networking configuration
    network {
      port "db" {
        static = 5432
        to     = 5432
      }
    }

    # Volume for persistent data
    volume "postgres-data" {
      type      = "host"
      source    = "webapp-data"
      read_only = false
    }

    # Service registration with Consul
    service {
      name = "postgres"
      port = "db"
      tags = [
        "database",
        "postgres",
        "primary",
        "demo"
      ]

      meta {
        version = "14"
        environment = "demo"
      }

      # Health checks
      check {
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }

      # Connect configuration for service mesh
      connect {
        sidecar_service {}
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
      size = 1000
    }

    task "postgres" {
      driver = "docker"

      config {
        image = "postgres:14-alpine"
        ports = ["db"]

        # Mount data volume
        mount {
          type     = "volume"
          target   = "/var/lib/postgresql/data"
          source   = "postgres-data"
          readonly = false
        }
      }

      # Environment variables for PostgreSQL
      env {
        POSTGRES_DB       = "webapp"
        POSTGRES_USER     = "postgres"
        POSTGRES_PASSWORD = "postgres-secret-password"
        PGDATA           = "/var/lib/postgresql/data/pgdata"
      }

      # Resources
      resources {
        cpu    = 200
        memory = 256
      }

      # Logs configuration
      logs {
        max_files     = 3
        max_file_size = 10
      }
    }
  }
}