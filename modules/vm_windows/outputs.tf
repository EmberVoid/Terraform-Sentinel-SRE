output "admin_username" {
  value       = azurerm_windows_virtual_machine.vm.admin_username
  description = "The admin username configured for this VM"
}

output "vm_id" {
  value       = azurerm_windows_virtual_machine.vm.id
  description = "The resource ID of the created Windows VM"
}

output "private_ip" {
  value       = azurerm_network_interface.nic.private_ip_address
  description = "The private IP address assigned to the VM"
}

output "public_ip" {
  value       = azurerm_public_ip.pip.ip_address
  description = "The public IP address assigned to the VM"
}
