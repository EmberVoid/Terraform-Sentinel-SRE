output "assignment_id" {
  description = "The ID of the Policy Assignment"
  value       = azurerm_resource_group_policy_assignment.this.id
}

output "remediation_id" {
  description = "The ID of the Policy Remediation task"
  value       = azurerm_resource_group_policy_remediation.this.id
}