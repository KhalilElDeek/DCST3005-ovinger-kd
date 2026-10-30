output "resource_group_name" {
  description = "Ressursgruppa stacken opprettet."
  value       = azurerm_resource_group.rg.name
}

output "vnet_name" {
  description = "Navnet på virtual network, videreformidlet fra modulen."
  value       = module.nett.vnet_name
}

output "subnet_ids" {
  description = "Map: subnett-navn => subnett-ID, videreformidlet fra modulen."
  value       = module.nett.subnet_ids
}
