output "vnet_id" {
  value       = azurerm_virtual_network.main.id
  description = "VNet ID"
}

output "vnet_name" {
  value       = azurerm_virtual_network.main.name
  description = "VNet name"
}

output "subnet_id" {
  value       = azurerm_subnet.main.id
  description = "Subnet ID"
}

output "subnet_name" {
  value       = azurerm_subnet.main.name
  description = "Subnet name"
}