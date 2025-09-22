variable "provider_choice" {
  description = "Cloud provider choice"
  type        = string
}

variable "vpc_id" {
  description = "VPC/Virtual Network ID"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the cluster"
  type        = list(string)
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_id" {
  description = "Unique cluster identifier"
  type        = string
}