variable "provider_choice" {
  description = "Cloud provider choice"
  type        = string
}

variable "region" {
  description = "Region for deployment"
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