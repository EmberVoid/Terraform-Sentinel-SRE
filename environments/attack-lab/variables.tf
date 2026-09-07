variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
  sensitive   = true
}

variable "environment" {
  type        = string
  description = "Environment name"
  default     = "attack-lab"
}

## 1. Resource Group variables — separate RG from dev, per the isolation design
variable "rg_name" {
  type        = string
  description = "Resource group name"
  default     = "rg-attack-lab-Sentinel-WUS3-01"
}

## 2. Network variables — separate VNet, no peering to dev's VNet
variable "vnet_name" {
  type        = string
  description = "Virtual network name"
  default     = "vnet-attack-lab-Sentinel-WUS3-01"
}

variable "subnet_name" {
  type        = string
  description = "Subnet name"
  default     = "attack-lab-subnet"
}

variable "client_ip" {
  type        = string
  description = "Client IP address for SSH/RDP access"
  sensitive   = true
}

## 3. VM variables
variable "kali_vm_name" {
  type        = string
  description = "Name of the Kali Linux attacker VM"
  default     = "Kali1-VM-AttackLab"
}

variable "target_vm_name" {
  type        = string
  description = "Name of the isolated Windows target VM"
  default     = "WinTarget1-VM-AttackLab"
}

variable "target_admin_password" {
  type        = string
  description = "Admin password for the isolated Windows target VM"
  sensitive   = true
}

variable "pub_key" {
  type        = string
  description = "SSH public key to add to the Kali VM"
  sensitive   = true
}

## 4. Cross-environment reference: dev's existing Log Analytics workspace,
## so this lab's telemetry lands in the same Sentinel instance without
## networking the two environments together (connect at the LAW level,
## not by bridging VNets — see security-lab-isolation skill)
variable "law_id" {
  type        = string
  description = "Resource ID of the existing (dev) Log Analytics workspace"

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.OperationalInsights/workspaces/[^/]+$", var.law_id))
    error_message = "law_id must be a full, correctly-cased Log Analytics workspace resource ID (resourceGroups and Microsoft.OperationalInsights are case-sensitive segments). Get it via: az monitor log-analytics workspace show --resource-group <rg> --workspace-name <name> --query id -o tsv"
  }
}
