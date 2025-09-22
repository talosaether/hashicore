#!/bin/bash
set -e

# Update system
apt-get update
apt-get install -y curl wget unzip jq

# Get instance metadata
if command -v curl >/dev/null 2>&1; then
    # Try AWS metadata service
    INSTANCE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null || echo "")
    if [ -z "$INSTANCE_IP" ]; then
        # Try Azure metadata service
        INSTANCE_IP=$(curl -s -H "Metadata:true" "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/privateIpAddress?api-version=2021-02-01&format=text" 2>/dev/null || echo "")
    fi
    if [ -z "$INSTANCE_IP" ]; then
        # Try GCP metadata service
        INSTANCE_IP=$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip" 2>/dev/null || echo "")
    fi
    if [ -z "$INSTANCE_IP" ]; then
        # Fallback to local IP
        INSTANCE_IP=$(hostname -I | awk '{print $1}')
    fi
else
    INSTANCE_IP=$(hostname -I | awk '{print $1}')
fi

# Create hashicorp user
useradd --system --home /etc/hashicorp --shell /bin/false hashicorp

# Create directories
mkdir -p /opt/hashicorp/{bin,data,config,logs}
mkdir -p /etc/hashicorp/{vault,consul,nomad}
chown -R hashicorp:hashicorp /opt/hashicorp /etc/hashicorp

# Download and install HashiCorp tools
cd /tmp

%{ if enable_vault ~}
# Install Vault
VAULT_VERSION="1.15.2"
wget https://releases.hashicorp.com/vault/$${VAULT_VERSION}/vault_$${VAULT_VERSION}_linux_amd64.zip
unzip vault_$${VAULT_VERSION}_linux_amd64.zip
mv vault /opt/hashicorp/bin/
rm vault_$${VAULT_VERSION}_linux_amd64.zip

# Create Vault configuration
cat > /etc/hashicorp/vault/vault.hcl <<EOF
storage "file" {
  path = "/opt/hashicorp/data/vault"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}

api_addr = "http://$${INSTANCE_IP}:8200"
cluster_addr = "http://$${INSTANCE_IP}:8201"
ui = true
disable_mlock = true
EOF

# Create Vault systemd service
cat > /etc/systemd/system/vault.service <<EOF
[Unit]
Description=HashiCorp Vault
Documentation=https://www.vaultproject.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/hashicorp/vault/vault.hcl

[Service]
Type=notify
User=hashicorp
Group=hashicorp
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/opt/hashicorp/bin/vault server -config=/etc/hashicorp/vault/vault.hcl
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF
%{ endif ~}

%{ if enable_consul ~}
# Install Consul
CONSUL_VERSION="1.17.0"
wget https://releases.hashicorp.com/consul/$${CONSUL_VERSION}/consul_$${CONSUL_VERSION}_linux_amd64.zip
unzip consul_$${CONSUL_VERSION}_linux_amd64.zip
mv consul /opt/hashicorp/bin/
rm consul_$${CONSUL_VERSION}_linux_amd64.zip

# Generate Consul encrypt key
CONSUL_ENCRYPT_KEY=$(head -c 32 /dev/urandom | base64)

# Create Consul configuration
cat > /etc/hashicorp/consul/consul.hcl <<EOF
datacenter = "dc1"
data_dir = "/opt/hashicorp/data/consul"
log_level = "INFO"
server = true
bootstrap_expect = ${cluster_size}
bind_addr = "$${INSTANCE_IP}"
client_addr = "0.0.0.0"
retry_join = ["$${INSTANCE_IP}"]
ui_config {
  enabled = true
}
connect {
  enabled = true
}
encrypt = "$${CONSUL_ENCRYPT_KEY}"
acl = {
  enabled = false
  default_policy = "allow"
}
EOF

# Create Consul systemd service
cat > /etc/systemd/system/consul.service <<EOF
[Unit]
Description=HashiCorp Consul
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/hashicorp/consul/consul.hcl

[Service]
Type=notify
User=hashicorp
Group=hashicorp
ExecStart=/opt/hashicorp/bin/consul agent -config-dir=/etc/hashicorp/consul/
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
%{ endif ~}

%{ if enable_nomad ~}
# Install Nomad
NOMAD_VERSION="1.6.4"
wget https://releases.hashicorp.com/nomad/$${NOMAD_VERSION}/nomad_$${NOMAD_VERSION}_linux_amd64.zip
unzip nomad_$${NOMAD_VERSION}_linux_amd64.zip
mv nomad /opt/hashicorp/bin/
rm nomad_$${NOMAD_VERSION}_linux_amd64.zip

# Install Docker for Nomad workloads
apt-get install -y docker.io
systemctl enable docker
systemctl start docker
usermod -aG docker hashicorp

# Create Nomad configuration
cat > /etc/hashicorp/nomad/nomad.hcl <<EOF
datacenter = "dc1"
data_dir = "/opt/hashicorp/data/nomad"
log_level = "INFO"

server {
  enabled = true
  bootstrap_expect = ${cluster_size}
}

client {
  enabled = true
  servers = ["$${INSTANCE_IP}:4647"]
}

bind_addr = "$${INSTANCE_IP}"

consul {
  address = "$${INSTANCE_IP}:8500"
}

vault {
  enabled = true
  address = "http://$${INSTANCE_IP}:8200"
}

ui {
  enabled = true
}

acl {
  enabled = false
}
EOF

# Create Nomad systemd service
cat > /etc/systemd/system/nomad.service <<EOF
[Unit]
Description=HashiCorp Nomad
Documentation=https://www.nomadproject.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/hashicorp/nomad/nomad.hcl

[Service]
Type=exec
User=hashicorp
Group=hashicorp
ExecStart=/opt/hashicorp/bin/nomad agent -config=/etc/hashicorp/nomad/
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
%{ endif ~}

# Set permissions
chmod +x /opt/hashicorp/bin/*
chown -R hashicorp:hashicorp /opt/hashicorp /etc/hashicorp

# Add HashiCorp binaries to PATH
echo 'export PATH=/opt/hashicorp/bin:$PATH' >> /etc/profile

# Enable and start services
systemctl daemon-reload

%{ if enable_vault ~}
systemctl enable vault
systemctl start vault
%{ endif ~}

%{ if enable_consul ~}
systemctl enable consul
systemctl start consul
%{ endif ~}

%{ if enable_nomad ~}
systemctl enable nomad
systemctl start nomad
%{ endif ~}

# Wait for services to start
sleep 30

# Initialize Vault (only on first node)
%{ if enable_vault ~}
if [ "$INSTANCE_IP" = "$(echo "$INSTANCE_IP" | head -n1)" ]; then
    export VAULT_ADDR=http://$${INSTANCE_IP}:8200
    /opt/hashicorp/bin/vault operator init -key-shares=1 -key-threshold=1 > /opt/hashicorp/vault-init.txt
    VAULT_UNSEAL_KEY=$(grep 'Unseal Key 1:' /opt/hashicorp/vault-init.txt | awk '{print $NF}')
    VAULT_ROOT_TOKEN=$(grep 'Initial Root Token:' /opt/hashicorp/vault-init.txt | awk '{print $NF}')

    /opt/hashicorp/bin/vault operator unseal $VAULT_UNSEAL_KEY

    # Store credentials in a file for easy access
    cat > /opt/hashicorp/vault-creds.txt <<EOF
VAULT_ADDR=http://$${INSTANCE_IP}:8200
VAULT_TOKEN=$VAULT_ROOT_TOKEN
VAULT_UNSEAL_KEY=$VAULT_UNSEAL_KEY
EOF
    chmod 600 /opt/hashicorp/vault-creds.txt
    chown hashicorp:hashicorp /opt/hashicorp/vault-creds.txt
fi
%{ endif ~}

echo "HashiStack installation completed on $(date)" >> /var/log/hashistack-install.log