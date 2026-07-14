variable "vnet_name" {
  type        = string
  description = "The name of the Virtual Network"
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group"
}

variable "location" {
  type        = string
  description = "The Azure region for the network infrastructure"
}

variable "address_space" {
  type        = list(string)
  description = "The address space for the VNet"
  default     = ["10.0.0.0/16"]
}

variable "subnet_name" {
  type        = string
  description = "The name of the single subnet"
  default     = "internal-subnet"
}

variable "subnet_prefix" {
  type        = string
  description = "The address prefix for the subnet"
  default     = "10.0.1.0/24"
}

variable "client_ip" {
  type        = string
  description = "The public IP address of the client machine for RDP access"
}
