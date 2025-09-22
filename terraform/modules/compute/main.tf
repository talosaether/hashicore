# Compute module for multi-cloud HashiStack deployment

# Data sources for AMIs and images
data "aws_ami" "ubuntu" {
  count = var.provider_choice == "aws" ? 1 : 0

  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "azurerm_platform_image" "ubuntu" {
  count = var.provider_choice == "azure" ? 1 : 0

  location  = var.region
  publisher = "Canonical"
  offer     = "0001-com-ubuntu-server-jammy"
  sku       = "22_04-lts-gen2"
}

# User data script for HashiStack installation
locals {
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    cluster_size  = var.cluster_size
    enable_vault  = var.enable_vault
    enable_consul = var.enable_consul
    enable_nomad  = var.enable_nomad
  }))
}

# SSH Key Pair
resource "aws_key_pair" "deployer" {
  count = var.provider_choice == "aws" ? 1 : 0

  key_name   = "${var.environment}-deployer-${var.cluster_id}"
  public_key = file(var.ssh_key_path)

  tags = {
    Name        = "${var.environment}-deployer-${var.cluster_id}"
    Environment = var.environment
  }
}

# AWS EC2 Instances
resource "aws_instance" "hashistack" {
  count = var.provider_choice == "aws" ? var.cluster_size : 0

  ami                     = data.aws_ami.ubuntu[0].id
  instance_type           = var.instance_type
  key_name                = aws_key_pair.deployer[0].key_name
  vpc_security_group_ids  = [var.security_group_id]
  subnet_id               = var.subnet_ids[count.index % length(var.subnet_ids)]
  user_data               = local.user_data
  disable_api_termination = false

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name         = "${var.environment}-hashistack-${count.index + 1}-${var.cluster_id}"
    Environment  = var.environment
    NodeIndex    = count.index
    NodeRole     = count.index == 0 ? "leader" : "follower"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Azure Public IPs
resource "azurerm_public_ip" "hashistack" {
  count = var.provider_choice == "azure" ? var.cluster_size : 0

  name                = "${var.environment}-hashistack-pip-${count.index + 1}-${var.cluster_id}"
  location            = var.region
  resource_group_name = data.azurerm_resource_group.main[0].name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = var.environment
  }
}

data "azurerm_resource_group" "main" {
  count = var.provider_choice == "azure" ? 1 : 0
  name  = split("/", var.subnet_ids[0])[4]  # Extract RG name from subnet ID
}

# Azure Network Interfaces
resource "azurerm_network_interface" "hashistack" {
  count = var.provider_choice == "azure" ? var.cluster_size : 0

  name                = "${var.environment}-hashistack-nic-${count.index + 1}-${var.cluster_id}"
  location            = var.region
  resource_group_name = data.azurerm_resource_group.main[0].name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_ids[count.index % length(var.subnet_ids)]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.hashistack[count.index].id
  }

  tags = {
    Environment = var.environment
  }
}

# Azure Network Security Group Association
resource "azurerm_network_interface_security_group_association" "hashistack" {
  count = var.provider_choice == "azure" ? var.cluster_size : 0

  network_interface_id      = azurerm_network_interface.hashistack[count.index].id
  network_security_group_id = var.security_group_id
}

# Azure Virtual Machines
resource "azurerm_linux_virtual_machine" "hashistack" {
  count = var.provider_choice == "azure" ? var.cluster_size : 0

  name                = "${var.environment}-hashistack-vm-${count.index + 1}-${var.cluster_id}"
  location            = var.region
  resource_group_name = data.azurerm_resource_group.main[0].name
  size                = var.instance_type
  admin_username      = "azureuser"

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.hashistack[count.index].id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.ssh_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = local.user_data

  tags = {
    Environment = var.environment
    NodeIndex   = count.index
    NodeRole    = count.index == 0 ? "leader" : "follower"
  }
}

# GCP Compute Instances
resource "google_compute_instance" "hashistack" {
  count = var.provider_choice == "gcp" ? var.cluster_size : 0

  name         = "${var.environment}-hashistack-${count.index + 1}-${var.cluster_id}"
  machine_type = var.instance_type
  zone         = "${var.region}-a"  # Simplified zone selection

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = var.subnet_ids[count.index % length(var.subnet_ids)]

    access_config {
      # Ephemeral public IP
    }
  }

  metadata = {
    ssh-keys   = "ubuntu:${file(var.ssh_key_path)}"
    user-data  = base64decode(local.user_data)
  }

  tags = ["hashistack"]

  labels = {
    environment = var.environment
    node-index  = count.index
    node-role   = count.index == 0 ? "leader" : "follower"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Local/Dummy Compute Resources (for testing)
resource "local_file" "compute_config" {
  count = var.provider_choice == "local" ? var.cluster_size : 0

  content = jsonencode({
    name         = "${var.environment}-hashistack-${count.index + 1}-${var.cluster_id}"
    instance_type = var.instance_type
    public_ip    = "192.168.1.${count.index + 10}"
    private_ip   = "10.0.1.${count.index + 10}"
    ssh_user     = "ubuntu"
    node_index   = count.index
    node_role    = count.index == 0 ? "leader" : "follower"
  })

  filename = "${path.module}/local-instance-${count.index + 1}-${var.cluster_id}.json"
}