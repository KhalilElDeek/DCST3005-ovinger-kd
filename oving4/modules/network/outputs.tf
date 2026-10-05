output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "subnet_ids" {
  description = "Map: subnett-navn => subnett-ID"
  value       = { for k, v in azurerm_subnet.main : k => v.id }
}

output "nsg_id" {
  value = azurerm_network_security_group.main.id
}