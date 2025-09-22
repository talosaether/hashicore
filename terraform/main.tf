terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Configure providers based on choice
provider "aws" {
  count  = var.provider_choice == "aws" ? 1 : 0
  region = var.region
}

provider "azurerm" {
  count = var.provider_choice == "azure" ? 1 : 0
  features {}
}

provider "google" {
  count   = var.provider_choice == "gcp" ? 1 : 0
  region  = var.region
}

# Random ID for unique resource naming
resource "random_id" "cluster" {
  byte_length = 4
}

# Network module
module "network" {
  source = "./modules/network"

  provider_choice    = var.provider_choice
  region            = var.region
  environment       = var.environment
  cluster_id        = random_id.cluster.hex
}

# Security module
module "security" {
  source = "./modules/security"

  provider_choice      = var.provider_choice
  vpc_id              = module.network.vpc_id
  allowed_cidr_blocks = var.allowed_cidr_blocks
  environment         = var.environment
  cluster_id          = random_id.cluster.hex

  depends_on = [module.network]
}

# Compute module
module "compute" {
  source = "./modules/compute"

  provider_choice     = var.provider_choice
  region             = var.region
  cluster_size       = var.cluster_size
  instance_type      = var.instance_type[var.provider_choice]
  subnet_ids         = module.network.subnet_ids
  security_group_id  = module.security.security_group_id
  ssh_key_path       = var.ssh_key_path
  environment        = var.environment
  cluster_id         = random_id.cluster.hex
  enable_vault       = var.enable_vault
  enable_consul      = var.enable_consul
  enable_nomad       = var.enable_nomad

  depends_on = [module.network, module.security]
}