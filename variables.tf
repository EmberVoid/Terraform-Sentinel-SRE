variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
  sensitive   = true          # hide it from plan output & logs
}

variable "client_IP" {
  type        = string        
  description = "Client IP address for SSH access"
  sensitive   = true
}

variable "pub_key" {
  type        = string        
  description = "SSH public key to add to the VM"
  sensitive   = true
}

variable "winser1_vm_dev_admin_password" {
  type        = string        
  description = "Admin password for the Windows VM"
  sensitive   = true
}