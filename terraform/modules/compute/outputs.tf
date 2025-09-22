output "public_ips" {
  description = "Public IP addresses of instances"
  value = var.provider_choice == "aws" ? (
    aws_instance.hashistack[*].public_ip
  ) : var.provider_choice == "azure" ? (
    azurerm_public_ip.hashistack[*].ip_address
  ) : var.provider_choice == "gcp" ? (
    google_compute_instance.hashistack[*].network_interface.0.access_config.0.nat_ip
  ) : [
    for i in range(var.cluster_size) :
    "192.168.1.${i + 10}"
  ]
}

output "private_ips" {
  description = "Private IP addresses of instances"
  value = var.provider_choice == "aws" ? (
    aws_instance.hashistack[*].private_ip
  ) : var.provider_choice == "azure" ? (
    azurerm_network_interface.hashistack[*].private_ip_address
  ) : var.provider_choice == "gcp" ? (
    google_compute_instance.hashistack[*].network_interface.0.network_ip
  ) : [
    for i in range(var.cluster_size) :
    "10.0.1.${i + 10}"
  ]
}

output "instance_ids" {
  description = "Instance IDs"
  value = var.provider_choice == "aws" ? (
    aws_instance.hashistack[*].id
  ) : var.provider_choice == "azure" ? (
    azurerm_linux_virtual_machine.hashistack[*].id
  ) : var.provider_choice == "gcp" ? (
    google_compute_instance.hashistack[*].id
  ) : [
    for i in range(var.cluster_size) :
    "local-instance-${i + 1}-${var.cluster_id}"
  ]
}

output "ssh_user" {
  description = "SSH username for instances"
  value = var.provider_choice == "aws" ? "ubuntu" : var.provider_choice == "azure" ? "azureuser" : var.provider_choice == "gcp" ? "ubuntu" : "ubuntu"
}