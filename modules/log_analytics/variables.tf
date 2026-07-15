variable "law_name" {
  type        = string
  description = "The name of the Log Analytics Workspace"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the existing resource group to deploy into"
}

variable "location" {
  type        = string
  description = "Azure region for the resources"
}