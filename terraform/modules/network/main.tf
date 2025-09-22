# Network module for multi-cloud HashiStack deployment

locals {
  vpc_cidr = "10.0.0.0/16"

  # Subnet CIDR blocks for different AZs
  subnet_cidrs = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24"
  ]
}

# AWS Network Resources
resource "aws_vpc" "main" {
  count = var.provider_choice == "aws" ? 1 : 0

  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-vpc-${var.cluster_id}"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "main" {
  count = var.provider_choice == "aws" ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = {
    Name        = "${var.environment}-igw-${var.cluster_id}"
    Environment = var.environment
  }
}

data "aws_availability_zones" "available" {
  count = var.provider_choice == "aws" ? 1 : 0
  state = "available"
}

resource "aws_subnet" "public" {
  count = var.provider_choice == "aws" ? length(local.subnet_cidrs) : 0

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = local.subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available[0].names[count.index % length(data.aws_availability_zones.available[0].names)]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.environment}-subnet-${count.index + 1}-${var.cluster_id}"
    Environment = var.environment
    Type        = "public"
  }
}

resource "aws_route_table" "public" {
  count = var.provider_choice == "aws" ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = {
    Name        = "${var.environment}-rt-public-${var.cluster_id}"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  count = var.provider_choice == "aws" ? length(aws_subnet.public) : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Azure Network Resources
resource "azurerm_resource_group" "main" {
  count = var.provider_choice == "azure" ? 1 : 0

  name     = "${var.environment}-rg-${var.cluster_id}"
  location = var.region
}

resource "azurerm_virtual_network" "main" {
  count = var.provider_choice == "azure" ? 1 : 0

  name                = "${var.environment}-vnet-${var.cluster_id}"
  address_space       = [local.vpc_cidr]
  location            = azurerm_resource_group.main[0].location
  resource_group_name = azurerm_resource_group.main[0].name
}

resource "azurerm_subnet" "public" {
  count = var.provider_choice == "azure" ? length(local.subnet_cidrs) : 0

  name                 = "${var.environment}-subnet-${count.index + 1}-${var.cluster_id}"
  resource_group_name  = azurerm_resource_group.main[0].name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = [local.subnet_cidrs[count.index]]
}

# GCP Network Resources
resource "google_compute_network" "main" {
  count = var.provider_choice == "gcp" ? 1 : 0

  name                    = "${var.environment}-network-${var.cluster_id}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public" {
  count = var.provider_choice == "gcp" ? length(local.subnet_cidrs) : 0

  name          = "${var.environment}-subnet-${count.index + 1}-${var.cluster_id}"
  ip_cidr_range = local.subnet_cidrs[count.index]
  region        = var.region
  network       = google_compute_network.main[0].id
}

# Local/Dummy Network Resources (for testing)
resource "local_file" "network_config" {
  count = var.provider_choice == "local" ? 1 : 0

  content = jsonencode({
    vpc_cidr     = local.vpc_cidr
    subnet_cidrs = local.subnet_cidrs
    environment  = var.environment
    cluster_id   = var.cluster_id
  })

  filename = "${path.module}/local-network-${var.cluster_id}.json"
}