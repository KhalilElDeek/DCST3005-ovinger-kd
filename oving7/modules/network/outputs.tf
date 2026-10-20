output "vnet_id" {
  description = "Ressurs-ID til virtual network."
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Navnet på virtual network."
  value       = azurerm_virtual_network.main.name
}

output "subnet_ids" {
  description = "Map: subnett-navn => subnett-ID"
  value       = { for k, v in azurerm_subnet.main : k => v.id }
}

output "resource_group_name" {
  value       = var.rg_name
  description = "Ressursgruppa (videreformidlet, til verifiseringssteg i workflowen)."
}
