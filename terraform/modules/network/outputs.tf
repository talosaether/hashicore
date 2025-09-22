output "vpc_id" {
  description = "VPC/Virtual Network ID"
  value = var.provider_choice == "aws" ? (
    length(aws_vpc.main) > 0 ? aws_vpc.main[0].id : null
  ) : var.provider_choice == "azure" ? (
    length(azurerm_virtual_network.main) > 0 ? azurerm_virtual_network.main[0].id : null
  ) : var.provider_choice == "gcp" ? (
    length(google_compute_network.main) > 0 ? google_compute_network.main[0].id : null
  ) : "local-vpc-${var.cluster_id}"
}

output "subnet_ids" {
  description = "Subnet IDs"
  value = var.provider_choice == "aws" ? (
    aws_subnet.public[*].id
  ) : var.provider_choice == "azure" ? (
    azurerm_subnet.public[*].id
  ) : var.provider_choice == "gcp" ? (
    google_compute_subnetwork.public[*].id
  ) : [
    "local-subnet-1-${var.cluster_id}",
    "local-subnet-2-${var.cluster_id}",
    "local-subnet-3-${var.cluster_id}"
  ]
}

output "resource_group_name" {
  description = "Azure Resource Group name (Azure only)"
  value = var.provider_choice == "azure" ? (
    length(azurerm_resource_group.main) > 0 ? azurerm_resource_group.main[0].name : null
  ) : null
}