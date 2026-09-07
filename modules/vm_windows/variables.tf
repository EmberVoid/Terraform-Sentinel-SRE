variable "vm_name" {
  type        = string
  description = "The name of the virtual machine"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the existing resource group to deploy into"
}

variable "location" {
  type        = string
  description = "Azure region for the resources"
}

variable "vm_size" {
  type        = string
  description = "The size/SKU of the virtual machine"
  default     = "Standard_B2s"
}

variable "admin_username" {
  type        = string
  description = "Username for the local administrator account"
  default     = "azureuser"
}

variable "admin_password" {
  type        = string
  description = "Password for the local administrator account"
  sensitive   = true
}

variable "computer_name" {
  type        = string
  description = "Windows NetBIOS computer name (max 15 chars). Leave null to let the provider auto-derive from vm_name — only safe when vm_name itself is <=15 chars."
  default     = null
}

variable "subnet_id" {
  type        = string
  description = "The ID of the subnet where the NIC should connect"
}