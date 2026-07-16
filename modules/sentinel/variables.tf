variable "law_id" {
  type        = string
  description = "The ID of the Log Analytics Workspace"
}

variable "subscription_id" {
  type        = string
  description = "The ID of the Azure subscription"
}

variable "location" {
  type        = string
  description = "Azure region for the policy assignment's managed identity"
}