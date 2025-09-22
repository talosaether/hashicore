#!/bin/bash
set -e

# Vault setup script for HashiStack demo
# This script should be run after Terraform deployment

VAULT_NODE=${1:-""}
if [ -z "$VAULT_NODE" ]; then
    echo "Usage: $0 <vault-node-ip>"
    echo "Example: $0 192.168.1.10"
    exit 1
fi

export VAULT_ADDR="http://${VAULT_NODE}:8200"
export VAULT_SKIP_VERIFY=true

echo "Setting up Vault at $VAULT_ADDR"

# Wait for Vault to be ready
echo "Waiting for Vault to be ready..."
for i in {1..30}; do
    if curl -s $VAULT_ADDR/v1/sys/health >/dev/null 2>&1; then
        echo "Vault is ready!"
        break
    fi
    echo "Waiting for Vault... ($i/30)"
    sleep 10
done

# Get Vault credentials from the instance
echo "Retrieving Vault credentials..."
VAULT_CREDS=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ubuntu@${VAULT_NODE} "sudo cat /opt/hashicorp/vault-creds.txt 2>/dev/null || echo 'not found'")

if [ "$VAULT_CREDS" = "not found" ]; then
    echo "Vault credentials not found. Initializing Vault..."

    # Initialize Vault
    INIT_OUTPUT=$(vault operator init -key-shares=1 -key-threshold=1 -format=json)
    UNSEAL_KEY=$(echo $INIT_OUTPUT | jq -r '.unseal_keys_b64[0]')
    ROOT_TOKEN=$(echo $INIT_OUTPUT | jq -r '.root_token')

    # Unseal Vault
    vault operator unseal $UNSEAL_KEY

    echo "Vault initialized successfully!"
    echo "Root Token: $ROOT_TOKEN"
    echo "Unseal Key: $UNSEAL_KEY"

    export VAULT_TOKEN=$ROOT_TOKEN
else
    # Parse existing credentials
    eval "$VAULT_CREDS"
    echo "Using existing Vault credentials"
fi

# Enable KV secrets engine
echo "Enabling KV secrets engine..."
vault secrets enable -path=secret kv-v2 2>/dev/null || echo "KV engine already enabled"

# Create example secrets
echo "Creating example secrets..."
vault kv put secret/apps/webapp \
    db_password="super-secret-password" \
    api_key="webapp-api-key-123" \
    debug_mode="false"

vault kv put secret/database/postgres \
    username="postgres" \
    password="postgres-secret-password" \
    host="postgres.service.consul" \
    port="5432" \
    database="webapp"

# Create policies
echo "Creating Vault policies..."
vault policy write nomad-server - <<EOF
# Policy for Nomad servers
path "auth/token/create/nomad-cluster" {
  capabilities = ["update"]
}

path "auth/token/roles/nomad-cluster" {
  capabilities = ["read"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/lookup" {
  capabilities = ["update"]
}

path "auth/token/revoke-accessor" {
  capabilities = ["update"]
}

path "auth/token/revoke" {
  capabilities = ["update"]
}

path "sys/capabilities-self" {
  capabilities = ["update"]
}
EOF

vault policy write webapp-policy - <<EOF
# Policy for webapp applications
path "secret/data/apps/webapp" {
  capabilities = ["read"]
}

path "secret/data/database/postgres" {
  capabilities = ["read"]
}
EOF

# Create token role for Nomad
echo "Creating token role for Nomad..."
vault write auth/token/roles/nomad-cluster \
    allowed_policies="webapp-policy" \
    explicit_max_ttl=0 \
    name="nomad-cluster" \
    orphan=true \
    period=259200 \
    renewable=true

# Create a token for Nomad
echo "Creating Nomad server token..."
NOMAD_TOKEN=$(vault write -field=token auth/token/create \
    policies="nomad-server" \
    period="72h" \
    no-default-policy=true)

echo ""
echo "=============================================="
echo "Vault setup completed successfully!"
echo "=============================================="
echo "Vault Address: $VAULT_ADDR"
echo "Root Token: $VAULT_TOKEN"
echo "Nomad Token: $NOMAD_TOKEN"
echo ""
echo "Example secrets created:"
echo "- secret/apps/webapp (contains db_password, api_key, debug_mode)"
echo "- secret/database/postgres (contains connection details)"
echo ""
echo "To use with Nomad, set this environment variable:"
echo "export VAULT_TOKEN=$NOMAD_TOKEN"
echo ""
echo "Test secret retrieval:"
echo "vault kv get secret/apps/webapp"
echo "=============================================="

# Save configuration for easy access
cat > vault-config.env <<EOF
export VAULT_ADDR=$VAULT_ADDR
export VAULT_TOKEN=$VAULT_TOKEN
export NOMAD_VAULT_TOKEN=$NOMAD_TOKEN
EOF

echo "Configuration saved to vault-config.env"
echo "Source it with: source vault-config.env"