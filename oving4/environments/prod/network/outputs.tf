output "subnet_ids" {
  value       = module.network.subnet_ids
  description = "Subnet-ID per subnettnavn. LESES AV APP-STACKEN."
}

output "vnet_id" {
  value = module.network.vnet_id
}