#Depends on the LAW being deployed already
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "sentinel" {
  workspace_id = var.law_id
}


data "azurerm_policy_definition" "activity_log_to_law" {
  display_name = "Configure Azure Activity logs to stream to specified Log Analytics workspace"
}

resource "azurerm_subscription_policy_assignment" "activity_log" {
  name                 = "activity-log-to-law"     # short, must be ≤64 chars
  display_name         = "Configure Azure Activity logs to stream to specified Log Analytics workspace"
  policy_definition_id = data.azurerm_policy_definition.activity_log_to_law.id
  subscription_id      = "/subscriptions/${var.subscription_id}"

  parameters = jsonencode({
    logAnalytics = { value = var.law_id }
  })

  identity { type = "SystemAssigned" }
  location = var.location
}

resource "azurerm_role_assignment" "activity_log_policy_identity" {
  scope                = var.law_id
  role_definition_name = "Log Analytics Contributor"
  principal_id          = azurerm_subscription_policy_assignment.activity_log.identity[0].principal_id
}

resource "azurerm_subscription_policy_remediation" "activity_log" {
  name                 = "remediate-activitylog-sentinel"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_assignment_id = azurerm_subscription_policy_assignment.activity_log.id
  depends_on           = [azurerm_role_assignment.activity_log_policy_identity]
}