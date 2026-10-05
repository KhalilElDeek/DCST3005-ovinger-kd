output "vnet_id" {
  value       = azurerm_virtual_network.main.id
  description = "VNet ID"
}

output "subnet_ids" {
  value       = { for k, v in azurerm_subnet.main : k => v.id }
  description = "Map of subnet name => subnet ID"
}

output "nsg_id" {
  value       = azurerm_network_security_group.main.id
  description = "Network security group ID"
}