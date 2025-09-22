# Security module for multi-cloud HashiStack deployment

# AWS Security Groups
resource "aws_security_group" "hashistack" {
  count = var.provider_choice == "aws" ? 1 : 0

  name_prefix = "${var.environment}-hashistack-${var.cluster_id}"
  vpc_id      = var.vpc_id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Vault API and UI
  ingress {
    description = "Vault API/UI"
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Consul API, UI, and DNS
  ingress {
    description = "Consul API/UI"
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress {
    description = "Consul DNS"
    from_port   = 8600
    to_port     = 8600
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress {
    description = "Consul DNS UDP"
    from_port   = 8600
    to_port     = 8600
    protocol    = "udp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Nomad API and UI
  ingress {
    description = "Nomad API/UI"
    from_port   = 4646
    to_port     = 4646
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Inter-cluster communication
  ingress {
    description = "Consul Serf LAN"
    from_port   = 8301
    to_port     = 8301
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Consul Serf LAN UDP"
    from_port   = 8301
    to_port     = 8301
    protocol    = "udp"
    self        = true
  }

  ingress {
    description = "Consul Serf WAN"
    from_port   = 8302
    to_port     = 8302
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Consul Serf WAN UDP"
    from_port   = 8302
    to_port     = 8302
    protocol    = "udp"
    self        = true
  }

  ingress {
    description = "Consul Server RPC"
    from_port   = 8300
    to_port     = 8300
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Nomad Server RPC"
    from_port   = 4647
    to_port     = 4647
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Nomad Serf"
    from_port   = 4648
    to_port     = 4648
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Nomad Serf UDP"
    from_port   = 4648
    to_port     = 4648
    protocol    = "udp"
    self        = true
  }

  # Vault cluster communication
  ingress {
    description = "Vault Cluster"
    from_port   = 8201
    to_port     = 8201
    protocol    = "tcp"
    self        = true
  }

  # Application ports (dynamic allocation range for Nomad)
  ingress {
    description = "Nomad Dynamic Ports"
    from_port   = 20000
    to_port     = 32000
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # HTTP/HTTPS for applications
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-hashistack-sg-${var.cluster_id}"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Azure Network Security Group
resource "azurerm_network_security_group" "hashistack" {
  count = var.provider_choice == "azure" ? 1 : 0

  name                = "${var.environment}-hashistack-nsg-${var.cluster_id}"
  location            = data.azurerm_resource_group.main[0].location
  resource_group_name = data.azurerm_resource_group.main[0].name

  # SSH
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.allowed_cidr_blocks
    destination_address_prefix = "*"
  }

  # Vault
  security_rule {
    name                       = "Vault"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8200"
    source_address_prefixes    = var.allowed_cidr_blocks
    destination_address_prefix = "*"
  }

  # Consul
  security_rule {
    name                       = "Consul"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["8500", "8600"]
    source_address_prefixes    = var.allowed_cidr_blocks
    destination_address_prefix = "*"
  }

  # Nomad
  security_rule {
    name                       = "Nomad"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4646"
    source_address_prefixes    = var.allowed_cidr_blocks
    destination_address_prefix = "*"
  }

  # HTTP/HTTPS
  security_rule {
    name                       = "Web"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefixes    = var.allowed_cidr_blocks
    destination_address_prefix = "*"
  }

  tags = {
    Environment = var.environment
  }
}

data "azurerm_resource_group" "main" {
  count = var.provider_choice == "azure" ? 1 : 0
  name  = split("/", var.vpc_id)[4]  # Extract RG name from VNet ID
}

# GCP Firewall Rules
resource "google_compute_firewall" "hashistack" {
  count = var.provider_choice == "gcp" ? 1 : 0

  name    = "${var.environment}-hashistack-fw-${var.cluster_id}"
  network = var.vpc_id

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "4646", "4647", "4648", "8200", "8201", "8300", "8301", "8302", "8500", "8600", "20000-32000"]
  }

  allow {
    protocol = "udp"
    ports    = ["8301", "8302", "8600", "4648"]
  }

  source_ranges = var.allowed_cidr_blocks
  target_tags   = ["hashistack"]
}

# Local/Dummy Security (for testing)
resource "local_file" "security_config" {
  count = var.provider_choice == "local" ? 1 : 0

  content = jsonencode({
    allowed_cidr_blocks = var.allowed_cidr_blocks
    environment         = var.environment
    cluster_id          = var.cluster_id
  })

  filename = "${path.module}/local-security-${var.cluster_id}.json"
}