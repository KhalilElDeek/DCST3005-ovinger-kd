output "vm_id" {
  value       = azurerm_linux_virtual_machine.main.id
  description = "VM ID"
}

output "vm_name" {
  value       = azurerm_linux_virtual_machine.main.name
  description = "VM name"
}

output "private_ip" {
  value       = azurerm_network_interface.main.private_ip_address
  description = "Private IP address"
}