output "name" {
  value       = azurerm_resource_group.rg.name
  description = "The name of the created resource group"
}

output "location" {
  value       = azurerm_resource_group.rg.location
  description = "The location/region of the created resource group"
}
