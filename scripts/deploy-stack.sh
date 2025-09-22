#!/bin/bash
set -e

# Complete HashiStack deployment script
# This script orchestrates the entire deployment process

echo "🚀 HashiStack Deployment Script"
echo "================================"

# Configuration
TERRAFORM_DIR="./terraform"
PROVIDER=${1:-"aws"}
CLUSTER_SIZE=${2:-3}

echo "Provider: $PROVIDER"
echo "Cluster Size: $CLUSTER_SIZE"
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed. Please install Terraform first."
    exit 1
fi

# Check if required tools are available
for tool in curl jq ssh; do
    if ! command -v $tool &> /dev/null; then
        echo "❌ $tool is not installed. Please install $tool first."
        exit 1
    fi
done

# Check SSH key
if [ ! -f ~/.ssh/id_rsa.pub ]; then
    echo "❌ SSH public key not found at ~/.ssh/id_rsa.pub"
    echo "Please generate an SSH key pair with: ssh-keygen -t rsa -b 4096"
    exit 1
fi

echo "✅ Prerequisites check passed"
echo ""

# Step 1: Deploy Infrastructure
echo "🏗️  Step 1: Deploying infrastructure with Terraform..."
cd $TERRAFORM_DIR

# Create terraform.tfvars if it doesn't exist
if [ ! -f terraform.tfvars ]; then
    echo "Creating terraform.tfvars..."
    cat > terraform.tfvars <<EOF
provider_choice = "$PROVIDER"
cluster_size = $CLUSTER_SIZE
environment = "hashistack-demo"
enable_vault = true
enable_consul = true
enable_nomad = true
EOF
fi

# Initialize and apply Terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Get outputs
CLUSTER_IPS=$(terraform output -json cluster_public_ips | jq -r '.[]' | tr '\n' ',' | sed 's/,$//')
FIRST_IP=$(terraform output -json cluster_public_ips | jq -r '.[0]')
SSH_USER=$(terraform output -raw cluster_ssh_user)

echo "✅ Infrastructure deployed successfully"
echo "Cluster IPs: $CLUSTER_IPS"
echo ""

cd ..

# Step 2: Wait for instances to be ready
echo "⏳ Step 2: Waiting for instances to be ready..."
IFS=',' read -ra IP_ARRAY <<< "$CLUSTER_IPS"

for ip in "${IP_ARRAY[@]}"; do
    echo "Waiting for $ip to be ready..."
    for i in {1..30}; do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ~/.ssh/id_rsa ${SSH_USER}@${ip} "echo 'ready'" &>/dev/null; then
            echo "✅ $ip is ready"
            break
        fi
        echo "Waiting... ($i/30)"
        sleep 10
    done
done

echo "✅ All instances are ready"
echo ""

# Step 3: Setup Vault
echo "🔐 Step 3: Setting up Vault..."
./vault/setup-vault.sh $FIRST_IP

# Source Vault configuration
if [ -f vault-config.env ]; then
    source vault-config.env
fi

echo "✅ Vault setup completed"
echo ""

# Step 4: Setup Consul
echo "🔗 Step 4: Setting up Consul..."
./consul/setup-consul.sh "$CLUSTER_IPS"

echo "✅ Consul setup completed"
echo ""

# Step 5: Setup Nomad
echo "🎯 Step 5: Setting up Nomad..."
if [ -n "$NOMAD_VAULT_TOKEN" ]; then
    ./nomad/setup-nomad.sh "$CLUSTER_IPS" "$NOMAD_VAULT_TOKEN"
else
    echo "❌ Vault token not found. Please run Vault setup first."
    exit 1
fi

echo "✅ Nomad setup completed"
echo ""

# Step 6: Display summary
echo "🎉 HashiStack deployment completed successfully!"
echo "=============================================="
echo ""
echo "🌐 Management UIs:"
echo "  Vault:  http://${FIRST_IP}:8200"
echo "  Consul: http://${FIRST_IP}:8500"
echo "  Nomad:  http://${FIRST_IP}:4646"
echo ""
echo "🔑 Access Information:"
echo "  SSH: ssh -i ~/.ssh/id_rsa ${SSH_USER}@${FIRST_IP}"
echo "  Configuration files: vault-config.env, consul-config.env, nomad-config.env"
echo ""
echo "🚀 Demo Application:"
echo "  Check Nomad UI for WebApp service endpoints"
echo "  The app demonstrates Vault secrets integration and Consul service discovery"
echo ""
echo "🧹 Cleanup:"
echo "  To destroy the infrastructure: cd terraform && terraform destroy"
echo ""
echo "=============================================="