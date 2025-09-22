# HashiStack Demo: Complete End-to-End Orchestration

A comprehensive demonstration of HashiCorp's infrastructure stack featuring Terraform, Vault, Consul, and Nomad working together in harmony.

## 🏗️ Architecture Overview

This demo implements a complete HashiStack deployment that showcases:

- **Terraform**: Multi-cloud infrastructure provisioning (AWS, Azure, GCP, or local)
- **Vault**: Secrets management with auto-unseal and secure token distribution
- **Consul**: Service discovery, health checking, and service mesh capabilities
- **Nomad**: Container orchestration with Vault integration and Consul service registration

### Component Integration

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Terraform  │───▶│   Vault     │───▶│   Consul    │
│Infrastructure│    │ Secrets Mgmt│    │Service Disc │
└─────────────┘    └─────────────┘    └─────────────┘
                           │                   │
                           ▼                   ▼
                   ┌─────────────────────────────────┐
                   │           Nomad                 │
                   │     Workload Orchestration      │
                   └─────────────────────────────────┘
```

## 📋 Prerequisites

Before running this demo, ensure you have:

### Required Tools
- **Terraform** (≥ 1.5): `brew install terraform` or [Download](https://terraform.io/downloads)
- **curl**: For API interactions
- **jq**: For JSON processing
- **ssh**: For remote access

### Cloud Provider Setup (choose one)
- **AWS**: AWS CLI configured with appropriate credentials
- **Azure**: Azure CLI logged in with subscription access
- **GCP**: gcloud CLI configured with project access
- **Local**: For testing without cloud resources

### SSH Key Pair
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

## 🚀 Quick Start

### Automated Deployment
The fastest way to get started:

```bash
# Clone and enter the project
git clone <this-repo>
cd hashicore

# Deploy everything with default settings (AWS, 3 nodes)
./scripts/deploy-stack.sh

# Or specify provider and cluster size
./scripts/deploy-stack.sh aws 3
./scripts/deploy-stack.sh azure 5
```

### Manual Step-by-Step Deployment

#### 1. Infrastructure Provisioning

```bash
cd terraform

# Copy and customize configuration
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars for your environment

# Deploy infrastructure
terraform init
terraform plan
terraform apply

# Note the output values
terraform output
```

#### 2. Vault Setup

```bash
# Get the first node IP from Terraform output
VAULT_NODE=$(terraform output -json cluster_public_ips | jq -r '.[0]')

# Setup Vault
./vault/setup-vault.sh $VAULT_NODE

# Source the generated configuration
source vault-config.env
```

#### 3. Consul Configuration

```bash
# Get all node IPs
CLUSTER_IPS=$(terraform output -json cluster_public_ips | jq -r '.[]' | tr '\n' ',' | sed 's/,$//')

# Setup Consul cluster
./consul/setup-consul.sh "$CLUSTER_IPS"

# Source the configuration
source consul-config.env
```

#### 4. Nomad Deployment

```bash
# Setup Nomad with Vault integration
./nomad/setup-nomad.sh "$CLUSTER_IPS" "$NOMAD_VAULT_TOKEN"

# Source the configuration
source nomad-config.env
```

## 🎯 Demo Applications

The deployment includes two example Nomad jobs that demonstrate the stack integration:

### WebApp Service
- **Technology**: Nginx serving dynamic HTML
- **Vault Integration**: Retrieves secrets at runtime using templates
- **Consul Integration**: Registers for service discovery with health checks
- **Features**:
  - Displays Vault secrets in web interface
  - Shows Nomad allocation information
  - Demonstrates service mesh connectivity

### PostgreSQL Database
- **Technology**: PostgreSQL 14 in Docker
- **Consul Integration**: Service registration with health monitoring
- **Persistence**: Uses Nomad host volumes
- **Networking**: Available via Consul service discovery

## 🔧 Configuration Reference

### Terraform Variables

| Variable | Description | Default | Options |
|----------|-------------|---------|---------|
| `provider_choice` | Cloud provider | `aws` | `aws`, `azure`, `gcp`, `local` |
| `cluster_size` | Number of nodes | `3` | `1-10` |
| `instance_type` | VM size per provider | `t3.medium` | Provider-specific |
| `region` | Deployment region | `us-west-2` | Provider-specific |
| `environment` | Environment name | `hashistack-demo` | Any string |

### Vault Policies

The demo creates these Vault policies:
- **nomad-server**: Allows Nomad to create tokens for jobs
- **webapp-policy**: Grants access to application secrets

### Consul Services

Registered services include:
- **webapp**: Web application with health checks
- **postgres**: Database service with TCP health check
- **nomad**: Nomad servers for auto-discovery
- **nomad-client**: Nomad clients

## 🌐 Management Interfaces

After deployment, access these web interfaces:

- **Vault UI**: `http://<first-node-ip>:8200`
- **Consul UI**: `http://<first-node-ip>:8500`
- **Nomad UI**: `http://<first-node-ip>:4646`
- **Demo WebApp**: Check Nomad UI for dynamic port assignments

## 🔍 Verification and Testing

### Service Discovery Tests
```bash
# DNS-based discovery (from cluster nodes)
dig @<node-ip> -p 8600 webapp.service.consul
dig @<node-ip> -p 8600 postgres.service.consul

# HTTP API discovery
curl http://<node-ip>:8500/v1/catalog/service/webapp
curl http://<node-ip>:8500/v1/health/service/postgres?passing
```

### Vault Secret Access
```bash
# Set Vault environment
export VAULT_ADDR=http://<node-ip>:8200
export VAULT_TOKEN=<your-token>

# Test secret retrieval
vault kv get secret/apps/webapp
vault kv get secret/database/postgres
```

### Nomad Operations
```bash
# Job management
nomad job status
nomad job status webapp
nomad job logs <allocation-id>

# Scaling
nomad job scale webapp 4
nomad job scale webapp 1

# Job inspection
nomad alloc status <allocation-id>
nomad alloc logs <allocation-id>
```

## 🔄 Operational Workflows

### Adding a New Service

1. **Create Nomad Job Specification**
```hcl
job "myapp" {
  datacenters = ["dc1"]

  group "app" {
    service {
      name = "myapp"
      port = "http"
      # ... health checks and tags
    }

    vault {
      policies = ["myapp-policy"]
    }

    task "web" {
      # ... task configuration
    }
  }
}
```

2. **Create Vault Policy**
```bash
vault policy write myapp-policy - <<EOF
path "secret/data/myapp/*" {
  capabilities = ["read"]
}
EOF
```

3. **Deploy the Job**
```bash
nomad job run myapp.nomad
```

### Updating Secrets
```bash
# Update application secrets
vault kv put secret/apps/webapp \
  db_password="new-secret-password" \
  api_key="updated-api-key"

# Restart job to pick up new secrets
nomad job restart webapp
```

### Scaling Operations
```bash
# Scale up for high load
nomad job scale webapp 6

# Scale down during low usage
nomad job scale webapp 2

# Auto-scaling can be implemented with external tools
```

## 🛡️ Security Considerations

### Production Hardening Checklist

- [ ] **Vault**:
  - Use proper storage backend (Consul, cloud storage)
  - Enable TLS encryption
  - Implement proper seal/unseal procedures
  - Configure audit logging
  - Use dynamic secrets where possible

- [ ] **Consul**:
  - Enable ACLs with proper policies
  - Configure TLS for all communications
  - Implement gossip encryption
  - Use Consul Connect for service mesh

- [ ] **Nomad**:
  - Enable ACLs for API access
  - Configure TLS encryption
  - Implement proper resource constraints
  - Use Consul Connect for secure networking

- [ ] **Infrastructure**:
  - Restrict security groups to necessary ports
  - Use private subnets for internal communication
  - Implement proper firewall rules
  - Enable encryption at rest

## 🧹 Cleanup

### Destroy Infrastructure
```bash
cd terraform
terraform destroy
```

### Clean Local Files
```bash
rm -f vault-config.env consul-config.env nomad-config.env
rm -f terraform/terraform.tfstate*
```

## 🐛 Troubleshooting

### Common Issues

**Vault Initialization Fails**
```bash
# Check Vault logs
ssh <node-ip> "sudo journalctl -u vault -f"

# Manual initialization
export VAULT_ADDR=http://<node-ip>:8200
vault operator init
```

**Consul Cluster Formation Issues**
```bash
# Check Consul logs
ssh <node-ip> "sudo journalctl -u consul -f"

# Check cluster members
consul members
```

**Nomad Jobs Fail to Start**
```bash
# Check job status
nomad job status <job-name>

# Check allocation details
nomad alloc status <alloc-id>
nomad alloc logs <alloc-id>
```

**Network Connectivity Issues**
```bash
# Test port accessibility
nc -zv <node-ip> 8200  # Vault
nc -zv <node-ip> 8500  # Consul
nc -zv <node-ip> 4646  # Nomad
```

### Debug Mode
```bash
# Enable debug logging for all services
export VAULT_LOG_LEVEL=DEBUG
export CONSUL_LOG_LEVEL=DEBUG
export NOMAD_LOG_LEVEL=DEBUG
```

## 📚 Further Reading

- [Terraform Documentation](https://terraform.io/docs)
- [Vault Documentation](https://vaultproject.io/docs)
- [Consul Documentation](https://consul.io/docs)
- [Nomad Documentation](https://nomadproject.io/docs)
- [HashiCorp Learn Tutorials](https://learn.hashicorp.com)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Happy HashiStacking! 🚀**