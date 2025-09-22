output "cluster_public_ips" {
  description = "Public IP addresses of cluster nodes"
  value       = module.compute.public_ips
}

output "cluster_private_ips" {
  description = "Private IP addresses of cluster nodes"
  value       = module.compute.private_ips
}

output "cluster_ssh_user" {
  description = "SSH username for cluster instances"
  value       = module.compute.ssh_user
}

output "vpc_id" {
  description = "VPC ID where cluster is deployed"
  value       = module.network.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs used by the cluster"
  value       = module.network.subnet_ids
}

output "security_group_id" {
  description = "Security group ID for cluster access"
  value       = module.security.security_group_id
}

output "vault_ui_url" {
  description = "Vault UI URL (first node)"
  value       = var.enable_vault ? "http://${module.compute.public_ips[0]}:8200" : null
}

output "consul_ui_url" {
  description = "Consul UI URL (first node)"
  value       = var.enable_consul ? "http://${module.compute.public_ips[0]}:8500" : null
}

output "nomad_ui_url" {
  description = "Nomad UI URL (first node)"
  value       = var.enable_nomad ? "http://${module.compute.public_ips[0]}:4646" : null
}

output "ssh_commands" {
  description = "SSH commands to connect to cluster nodes"
  value = [
    for i, ip in module.compute.public_ips :
    "ssh -i ${replace(var.ssh_key_path, ".pub", "")} ${module.compute.ssh_user}@${ip}"
  ]
}