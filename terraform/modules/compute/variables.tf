variable "provider_choice" {
  description = "Cloud provider choice"
  type        = string
}

variable "region" {
  description = "Region for deployment"
  type        = string
}

variable "cluster_size" {
  description = "Number of nodes in the cluster"
  type        = number
}

variable "instance_type" {
  description = "Instance type/size for virtual machines"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for instance placement"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for instances"
  type        = string
}

variable "ssh_key_path" {
  description = "Path to SSH public key"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_id" {
  description = "Unique cluster identifier"
  type        = string
}

variable "enable_vault" {
  description = "Enable Vault deployment"
  type        = bool
}

variable "enable_consul" {
  description = "Enable Consul deployment"
  type        = bool
}

variable "enable_nomad" {
  description = "Enable Nomad deployment"
  type        = bool
}