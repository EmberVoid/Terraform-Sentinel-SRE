# Policy assignment
resource "azurerm_resource_group_policy_assignment" "this" {
  name                 = var.name
  display_name         = var.display_name
  policy_definition_id = var.policy_definition_id
  resource_group_id    = var.scope
  location             = var.location

  identity {
    type = "SystemAssigned"
  }

  parameters = var.parameters
}

# Role assignment (RG)
# Dynamically assign as many roles as this specific policy needs
resource "azurerm_role_assignment" "this" {
  for_each             = toset(var.role_definitions)
  scope                = var.scope
  role_definition_name = each.key
  principal_id         = azurerm_resource_group_policy_assignment.this.identity[0].principal_id
}

# Remediation block
resource "azurerm_resource_group_policy_remediation" "this" {
  name                    = "${var.name}-remediation"
  resource_group_id       = var.scope
  policy_assignment_id    = azurerm_resource_group_policy_assignment.this.id
  resource_discovery_mode = "ReEvaluateCompliance"
}