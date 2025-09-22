#!/bin/bash
set -e

export CONSUL_HTTP_ADDR=http://localhost:8500

echo "🔗 Setting up Consul services..."

# Register sample services
echo "Registering sample services..."

# Register a sample database service
docker exec consul-dev consul services register -address=postgres.service.consul -port=5432 -name=postgres -tag=database -tag=primary

# Register a sample web service (placeholder)
docker exec consul-dev consul services register -address=webapp.service.consul -port=8080 -name=webapp -tag=web -tag=frontend

# Create KV entries for configuration
echo "Creating sample KV entries..."
docker exec consul-dev consul kv put config/webapp/database/host "postgres.service.consul"
docker exec consul-dev consul kv put config/webapp/database/port "5432"
docker exec consul-dev consul kv put config/webapp/database/name "webapp"
docker exec consul-dev consul kv put config/webapp/debug "false"
docker exec consul-dev consul kv put config/webapp/log_level "INFO"

echo "✅ Consul setup completed!"
echo "You can access Consul at: http://localhost:8500"