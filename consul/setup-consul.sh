#!/bin/bash
set -e

# Consul setup script for HashiStack demo
# This script should be run after Terraform deployment

CONSUL_NODES=${1:-""}
if [ -z "$CONSUL_NODES" ]; then
    echo "Usage: $0 \"<consul-node-ips>\""
    echo "Example: $0 \"192.168.1.10,192.168.1.11,192.168.1.12\""
    exit 1
fi

# Parse comma-separated IPs
IFS=',' read -ra NODE_IPS <<< "$CONSUL_NODES"
FIRST_NODE=${NODE_IPS[0]}

export CONSUL_HTTP_ADDR="http://${FIRST_NODE}:8500"

echo "Setting up Consul cluster with nodes: ${CONSUL_NODES}"
echo "Primary node: $FIRST_NODE"

# Wait for Consul to be ready
echo "Waiting for Consul to be ready..."
for i in {1..30}; do
    if curl -s $CONSUL_HTTP_ADDR/v1/status/leader >/dev/null 2>&1; then
        echo "Consul is ready!"
        break
    fi
    echo "Waiting for Consul... ($i/30)"
    sleep 10
done

# Check cluster status
echo "Checking Consul cluster status..."
consul members

# Register sample services
echo "Registering sample services..."

# Register a sample database service
consul services register - <<EOF
{
  "ID": "postgres-1",
  "Name": "postgres",
  "Tags": ["database", "primary"],
  "Address": "${FIRST_NODE}",
  "Port": 5432,
  "Meta": {
    "version": "14.9",
    "environment": "demo"
  },
  "Check": {
    "Name": "PostgreSQL Health Check",
    "TCP": "${FIRST_NODE}:5432",
    "Interval": "30s",
    "Timeout": "10s"
  }
}
EOF

# Register a sample web service
consul services register - <<EOF
{
  "ID": "webapp-1",
  "Name": "webapp",
  "Tags": ["web", "frontend"],
  "Address": "${FIRST_NODE}",
  "Port": 8080,
  "Meta": {
    "version": "1.0.0",
    "environment": "demo"
  },
  "Check": {
    "Name": "WebApp Health Check",
    "HTTP": "http://${FIRST_NODE}:8080/health",
    "Interval": "30s",
    "Timeout": "10s"
  }
}
EOF

# Create KV entries for configuration
echo "Creating sample KV entries..."
consul kv put config/webapp/database/host "postgres.service.consul"
consul kv put config/webapp/database/port "5432"
consul kv put config/webapp/database/name "webapp"
consul kv put config/webapp/debug "false"
consul kv put config/webapp/log_level "INFO"

# Set up prepared queries for service discovery
echo "Creating prepared queries..."
consul connect intention create webapp postgres

# Create a prepared query for database failover
curl -X POST $CONSUL_HTTP_ADDR/v1/query \
    -d '{
        "Name": "postgres-primary",
        "Service": {
            "Service": "postgres",
            "Tags": ["primary"],
            "Failover": {
                "NearestN": 2
            }
        }
    }'

echo ""
echo "=============================================="
echo "Consul setup completed successfully!"
echo "=============================================="
echo "Consul UI: $CONSUL_HTTP_ADDR"
echo ""
echo "Registered Services:"
consul catalog services

echo ""
echo "Sample KV entries:"
consul kv get -recurse config/

echo ""
echo "DNS queries (run these from cluster nodes):"
echo "dig @${FIRST_NODE} -p 8600 postgres.service.consul"
echo "dig @${FIRST_NODE} -p 8600 webapp.service.consul"
echo ""
echo "Service discovery examples:"
echo "curl $CONSUL_HTTP_ADDR/v1/catalog/service/postgres"
echo "curl $CONSUL_HTTP_ADDR/v1/health/service/webapp"
echo "=============================================="

# Save configuration
cat > consul-config.env <<EOF
export CONSUL_HTTP_ADDR=$CONSUL_HTTP_ADDR
export CONSUL_NODES="$CONSUL_NODES"
EOF

echo "Configuration saved to consul-config.env"
echo "Source it with: source consul-config.env"