locals {
  policy_definition_ids = {
    Linux   = "/providers/Microsoft.Authorization/policyDefinitions/2ea82cdd-f2e8-4500-af75-67a2e084ca74" //Configure Linux Machines to be associated with a Data Collection Rule or a Data Collection Endpoint
    Windows = "/providers/Microsoft.Authorization/policyDefinitions/eab1f514-22e3-42e3-9a1f-e1dc9199355c" //Configure Windows Machines to be associated with a Data Collection Rule or a Data Collection Endpoint
  }
  assignments_map = { for a in var.assignments : a.key => a }
}

module "dcr_association" {
  source   = "../general_rg_policy" # Path to the generic module
  for_each = { for a in var.assignments : a.key => a }

  name                 = substr("dcra-${each.key}", 0, 24)
  display_name         = each.value.display_name
  policy_definition_id = local.policy_definition_ids[each.value.os_type]
  scope                = coalesce(each.value.scope, var.scope)
  location             = var.location

  parameters = jsonencode({
    dcrResourceId = { value = each.value.dcr_resource_id }
    resourceType  = { value = each.value.resource_type }
    effect        = { value = each.value.effect }
  })

  # Pass both roles as a list
  role_definitions = [
    "Monitoring Contributor",
    "Log Analytics Contributor"
  ]
}