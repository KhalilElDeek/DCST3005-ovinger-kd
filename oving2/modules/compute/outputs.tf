output "vm_id" {
  value       = azurerm_linux_virtual_machine.main.id
  description = "Virtual machine ID"
}

output "vm_name" {
  value       = azurerm_linux_virtual_machine.main.name
  description = "Virtual machine name"
}

output "nic_id" {
  value       = azurerm_network_interface.main.id
  description = "Network interface ID"
}

output "nic_private_ip" {
  value       = azurerm_network_interface.main.private_ip_address
  description = "Private IP address"
}