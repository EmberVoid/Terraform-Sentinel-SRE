variable "name" {
  type = string
}

variable "display_name" {
  type = string
}

variable "policy_definition_id" {
  type = string
}

variable "scope" {
  type = string
}

variable "location" {
  type = string
}

variable "parameters" {
  type = string
}

variable "role_definitions" {
  type        = list(string)
  description = "List of RBAC roles the managed identity requires to remediate."
}