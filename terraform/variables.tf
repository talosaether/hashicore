variable "provider_choice" {
  description = "Choose cloud provider: aws, azure, gcp, or local"
  type        = string
  default     = "aws"

  validation {
    condition     = contains(["aws", "azure", "gcp", "local"], var.provider_choice)
    error_message = "Provider must be one of: aws, azure, gcp, local."
  }
}

variable "region" {
  description = "Region for cloud deployment"
  type        = string
  default     = "us-west-2"
}

variable "cluster_size" {
  description = "Number of nodes in the cluster"
  type        = number
  default     = 3

  validation {
    condition     = var.cluster_size >= 1 && var.cluster_size <= 10
    error_message = "Cluster size must be between 1 and 10."
  }
}

variable "instance_type" {
  description = "Instance type/size for virtual machines"
  type        = map(string)
  default = {
    aws   = "t3.medium"
    azure = "Standard_B2s"
    gcp   = "e2-medium"
    local = "medium"
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "hashistack-demo"
}

variable "ssh_key_path" {
  description = "Path to SSH public key for instance access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the cluster"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # For demo only - restrict in production
}

variable "enable_vault" {
  description = "Enable Vault deployment"
  type        = bool
  default     = true
}

variable "enable_consul" {
  description = "Enable Consul deployment"
  type        = bool
  default     = true
}

variable "enable_nomad" {
  description = "Enable Nomad deployment"
  type        = bool
  default     = true
}