variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
  sensitive   = true          # hide it from plan output & logs
}

variable "client_ip" {
  type        = string
  description = "Client IP address for SSH access"
  sensitive   = true
}

variable "WinSer1-VM-Dev_admin_password" {
  type        = string
  description = "Admin password for the Windows VM"
  sensitive   = true
}

variable "pub_key" {
  type        = string
  description = "SSH public key to add to the VM"
  sensitive   = true
}