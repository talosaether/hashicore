#!/bin/bash
set -e

# Nomad setup script for HashiStack demo
# This script should be run after Terraform deployment and Vault setup

NOMAD_NODES=${1:-""}
VAULT_TOKEN=${2:-""}

if [ -z "$NOMAD_NODES" ] || [ -z "$VAULT_TOKEN" ]; then
    echo "Usage: $0 \"<nomad-node-ips>\" \"<vault-token>\""
    echo "Example: $0 \"192.168.1.10,192.168.1.11,192.168.1.12\" \"s.abc123def456\""
    echo ""
    echo "You can get the Vault token by running the Vault setup script first"
    exit 1
fi

# Parse comma-separated IPs
IFS=',' read -ra NODE_IPS <<< "$NOMAD_NODES"
FIRST_NODE=${NODE_IPS[0]}

export NOMAD_ADDR="http://${FIRST_NODE}:4646"

echo "Setting up Nomad cluster with nodes: ${NOMAD_NODES}"
echo "Primary node: $FIRST_NODE"
echo "Using Vault token: ${VAULT_TOKEN:0:8}..."

# Configure Vault token on all nodes
echo "Configuring Vault integration on all nodes..."
for node in "${NODE_IPS[@]}"; do
    echo "Configuring node $node..."
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ubuntu@${node} "
        echo 'export VAULT_TOKEN=$VAULT_TOKEN' | sudo tee -a /etc/environment
        echo 'export VAULT_ADDR=http://${node}:8200' | sudo tee -a /etc/environment
        sudo systemctl restart nomad
    " &
done

# Wait for all background jobs to complete
wait

# Wait for Nomad to be ready
echo "Waiting for Nomad to be ready..."
for i in {1..30}; do
    if curl -s $NOMAD_ADDR/v1/status/leader >/dev/null 2>&1; then
        echo "Nomad is ready!"
        break
    fi
    echo "Waiting for Nomad... ($i/30)"
    sleep 10
done

# Check cluster status
echo "Checking Nomad cluster status..."
nomad server members
nomad node status

# Submit PostgreSQL job
echo "Submitting PostgreSQL job..."
nomad job run /home/fnuser/dev/repos/hashicore/nomad/postgres.nomad

# Wait for PostgreSQL to be running
echo "Waiting for PostgreSQL to be running..."
for i in {1..30}; do
    if nomad job status postgres | grep -q "Status.*running"; then
        echo "PostgreSQL is running!"
        break
    fi
    echo "Waiting for PostgreSQL... ($i/30)"
    sleep 10
done

# Submit WebApp job
echo "Submitting WebApp job..."
nomad job run /home/fnuser/dev/repos/hashicore/nomad/webapp.nomad

# Wait for WebApp to be running
echo "Waiting for WebApp to be running..."
for i in {1..30}; do
    if nomad job status webapp | grep -q "Status.*running"; then
        echo "WebApp is running!"
        break
    fi
    echo "Waiting for WebApp... ($i/30)"
    sleep 10
done

# Get allocation information
echo "Getting job allocation information..."
WEBAPP_ALLOCS=$(nomad job allocs webapp | tail -n +2 | head -n 2 | awk '{print $1}')
POSTGRES_ALLOC=$(nomad job allocs postgres | tail -n +2 | head -n 1 | awk '{print $1}')

echo ""
echo "=============================================="
echo "Nomad setup completed successfully!"
echo "=============================================="
echo "Nomad UI: $NOMAD_ADDR"
echo ""
echo "Deployed Jobs:"
nomad job status -short

echo ""
echo "Service Endpoints:"

# Get WebApp endpoints
for alloc in $WEBAPP_ALLOCS; do
    ALLOC_INFO=$(nomad alloc status $alloc)
    NODE_IP=$(echo "$ALLOC_INFO" | grep "Node IP" | awk '{print $3}')
    PORT=$(echo "$ALLOC_INFO" | grep -A5 "Port.*Label" | grep "http" | awk '{print $2}')
    if [ -n "$NODE_IP" ] && [ -n "$PORT" ]; then
        echo "WebApp: http://${NODE_IP}:${PORT}"
    fi
done

echo ""
echo "Job Management Commands:"
echo "nomad job status webapp"
echo "nomad job status postgres"
echo "nomad alloc logs \${ALLOC_ID}"
echo "nomad job stop webapp"
echo "nomad job stop postgres"

echo ""
echo "Service Discovery Verification:"
echo "curl http://${FIRST_NODE}:8500/v1/catalog/service/webapp"
echo "curl http://${FIRST_NODE}:8500/v1/catalog/service/postgres"

echo ""
echo "Scaling Examples:"
echo "nomad job scale webapp 4"
echo "nomad job scale webapp 1"

echo "=============================================="

# Save configuration
cat > nomad-config.env <<EOF
export NOMAD_ADDR=$NOMAD_ADDR
export NOMAD_NODES="$NOMAD_NODES"
export VAULT_TOKEN=$VAULT_TOKEN
EOF

echo "Configuration saved to nomad-config.env"
echo "Source it with: source nomad-config.env"