output "security_group_id" {
  description = "Security Group/NSG ID"
  value = var.provider_choice == "aws" ? (
    length(aws_security_group.hashistack) > 0 ? aws_security_group.hashistack[0].id : null
  ) : var.provider_choice == "azure" ? (
    length(azurerm_network_security_group.hashistack) > 0 ? azurerm_network_security_group.hashistack[0].id : null
  ) : var.provider_choice == "gcp" ? (
    length(google_compute_firewall.hashistack) > 0 ? google_compute_firewall.hashistack[0].name : null
  ) : "local-sg-${var.cluster_id}"
}