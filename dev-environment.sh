#!/bin/bash
set -e

# Development environment setup for HashiStack
# This runs HashiCorp tools locally using Docker

echo "🚀 Starting HashiStack Development Environment"
echo "=============================================="

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "❌ Docker is required but not installed."; exit 1; }

# Create network for services
docker network create hashistack-dev 2>/dev/null || echo "Network already exists"

# Start Consul
echo "📋 Starting Consul..."
docker run -d \
  --name consul-dev \
  --network hashistack-dev \
  -p 8500:8500 \
  -p 8600:8600/udp \
  hashicorp/consul:latest \
  agent -dev -ui -client=0.0.0.0 -log-level=INFO

# Wait for Consul
sleep 5

# Start Vault
echo "🔐 Starting Vault..."
docker run -d \
  --name vault-dev \
  --network hashistack-dev \
  -p 8200:8200 \
  --cap-add=IPC_LOCK \
  -e 'VAULT_DEV_ROOT_TOKEN_ID=myroot' \
  -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' \
  hashicorp/vault:latest

# Wait for Vault
sleep 5

# Start Nomad
echo "🎯 Starting Nomad..."
docker run -d \
  --name nomad-dev \
  --network hashistack-dev \
  -p 4646:4646 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --privileged \
  hashicorp/nomad:latest \
  agent -dev -bind=0.0.0.0 -log-level=INFO

# Wait for Nomad
sleep 10

echo "✅ All services started!"
echo ""
echo "🌐 Service URLs:"
echo "  Consul UI:  http://localhost:8500"
echo "  Vault UI:   http://localhost:8200 (token: myroot)"
echo "  Nomad UI:   http://localhost:4646"
echo ""
echo "🔧 Setup commands will be run next..."