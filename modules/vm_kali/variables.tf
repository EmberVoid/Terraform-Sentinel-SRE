variable "vm_name" {
  type        = string
  description = "The name of the Kali Linux virtual machine"
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
  default     = "Standard_B2als_v2"
}

variable "admin_username" {
  type        = string
  description = "Username for the local administrator account"
  default     = "kaliattacker"
}

variable "pub_key" {
  type        = string
  description = "SSH public key to add to the VM"
  sensitive   = true
}

variable "subnet_id" {
  type        = string
  description = "The ID of the subnet where the NIC should connect"
}

variable "kali_version" {
  type        = string
  description = "Kali marketplace image SKU (matches the offer's plan name). Verify against `az vm image list --publisher kali-linux --all` before changing — the portal's display label (e.g. 'x64 Gen2') does not match the actual SKU string."
  default     = "kali-2026-2"
}
