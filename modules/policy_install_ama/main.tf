locals {
  ama_linux_policy_id   = "/providers/Microsoft.Authorization/policyDefinitions/a4034bc6-ae50-406d-bf76-50f4ee5a7811" //Configure Linux virtual machines to run Azure Monitor Agent with system-assigned managed identity-based authentication
  ama_windows_policy_id = "/providers/Microsoft.Authorization/policyDefinitions/ca817e41-e85a-4783-bc7f-dc532d36235e" //Configure Windows virtual machines to run Azure Monitor Agent using system-assigned managed identity
}

module "ama_linux" {
  source = "../general_rg_policy"
  count  = var.enable_linux ? 1 : 0

  name                 = substr("${var.assignment_name_prefix}-linux", 0, 24)
  display_name         = "Configure Linux VMs to run AMA (SAMI)"
  policy_definition_id = local.ama_linux_policy_id
  scope                = var.scope
  location             = var.location

  parameters = jsonencode({ effect = { value = var.effect } })
  role_definitions = ["Virtual Machine Contributor"]
}

module "ama_windows" {
  source = "../general_rg_policy"
  count  = var.enable_windows ? 1 : 0

  name                 = substr("${var.assignment_name_prefix}-windows", 0, 24)
  display_name         = "Configure Windows VMs to run AMA (SAMI)"
  policy_definition_id = local.ama_windows_policy_id
  scope                = var.scope
  location             = var.location

  parameters = jsonencode({ effect = { value = var.effect } })
  role_definitions = ["Virtual Machine Contributor"]
}