#!/bin/bash
set -e

export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=myroot
export VAULT_SKIP_VERIFY=true

echo "🔐 Setting up Vault secrets for dev environment..."

# Enable KV secrets engine
docker exec vault-dev vault secrets enable -path=secret kv-v2 2>/dev/null || echo "KV engine already enabled"

# Create example secrets
echo "Creating application secrets..."
docker exec -e VAULT_TOKEN=myroot -e VAULT_ADDR=http://localhost:8200 vault-dev vault kv put secret/apps/webapp \
    db_password="super-secret-password" \
    api_key="webapp-api-key-123" \
    debug_mode="false"

docker exec -e VAULT_TOKEN=myroot -e VAULT_ADDR=http://localhost:8200 vault-dev vault kv put secret/database/postgres \
    username="postgres" \
    password="postgres-secret-password" \
    host="postgres.service.consul" \
    port="5432" \
    database="webapp"

# Create policies
echo "Creating Vault policies..."
docker exec -e VAULT_TOKEN=myroot -e VAULT_ADDR=http://localhost:8200 vault-dev vault policy write webapp-policy - <<EOF
path "secret/data/apps/webapp" {
  capabilities = ["read"]
}

path "secret/data/database/postgres" {
  capabilities = ["read"]
}
EOF

echo "✅ Vault setup completed!"
echo "You can access Vault at: http://localhost:8200 (token: myroot)"