## Provider and Terraform configuration
terraform {
  required_version = ">= 1.9.0" # TFLint checks this constraint

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  resource_provider_registrations = "none"
  subscription_id                 = var.subscription_id
  features {}
}

## 1. Resource Group — separate from dev, per the isolation design.
## Attack-sim/target boxes get their own blast-radius boundary from
## anything Sentinel-integrated in dev — no shared RG, no peering.
module "rg" {
  source   = "../../modules/resource_group"
  rg_name  = var.rg_name
  location = "westus3"
  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "attack-simulation-isolated"
  }
}

## 2. Networking — separate VNet, NO peering to dev's VNet.
## Cross-lab visibility is handled at the Log Analytics level (var.law_id
## below), not by bridging networks.
module "network" {
  source        = "../../modules/network"
  vnet_name     = var.vnet_name
  address_space = ["10.124.0.0/16"]
  subnet_name   = var.subnet_name
  subnet_prefix = "10.124.1.0/24"
  client_ip     = var.client_ip

  # CHAINED OUTPUTS
  resource_group_name = module.rg.name
  location            = module.rg.location
}

## 3. Kali Linux attacker VM
module "Kali1_VM" {
  source  = "../../modules/vm_kali"
  vm_name = var.kali_vm_name

  pub_key = var.pub_key

  # CHAINED OUTPUTS
  resource_group_name = module.rg.name
  location            = module.rg.location
  subnet_id           = module.network.subnet_id
}

## 4. Isolated Windows target VM (reusing the existing vm_windows module)
module "WinTarget1_VM" {
  source  = "../../modules/vm_windows"
  vm_name = var.target_vm_name
  vm_size = "Standard_B2als_v2"

  admin_username = "targetadmin"
  admin_password = var.target_admin_password
  computer_name  = "AttackTarget1" # NetBIOS cap is 15 chars; vm_name itself stays descriptive

  # CHAINED OUTPUTS
  resource_group_name = module.rg.name
  location            = module.rg.location
  subnet_id           = module.network.subnet_id
}

## 5. Reuse dev's Sentinel/Log Analytics workspace — DCR pointed at the SAME
## workspace (var.law_id). No second Sentinel instance, no network bridge
## back to dev.
module "dcr_attacklab_windows_security" {
  source = "../../modules/dcr"

  name        = "dcr_attacklab_windows_security"
  kind        = "Windows"
  description = "Sentinel: Attack Lab Windows Security Events via AMA"

  # CHAINED OUTPUTS
  resource_group_name = module.rg.name
  location            = module.rg.location
  law_id              = var.law_id

  data_flows = [
    {
      streams       = ["Microsoft-SecurityEvent"]
      output_stream = "Microsoft-SecurityEvent"
    }
  ]

  windows_event_logs = [
    {
      name           = "AttackLabWindowsSecurityEvents"
      streams        = ["Microsoft-SecurityEvent"]
      x_path_queries = ["Security!*"]
    }
  ]
}

## 6. Policy assignments scoped to THIS RG only (own copy, not shared with dev).
## Same effect as dev's policy_install_ama/policy_dcr_association — AMA
## auto-install + DCR association enforced at the policy level — but isolated
## to rg-attack-lab's own scope so managing this lab never touches dev's policy
## assignments or state.
module "policy_install_ama" {
  source = "../../modules/policy_install_ama"

  assignment_name_prefix = "ama-install-attacklab"

  # CHAINED OUTPUTS
  scope    = module.rg.id
  location = module.rg.location

  # enable_linux left at its module default (true) is harmless but pointless:
  # confirmed via the built-in policy's own definition (a4034bc6-...) that its
  # imagePublisher/imageOffer allowlist has no kali-linux/kali entry, so the
  # Kali VM is silently out of scope for this policy (not non-compliant, not
  # evaluated at all — az policy state list returns zero rows for it even
  # after a forced trigger-scan). This is expected, not a bug: the attacker
  # box isn't meant to self-report telemetry into the same Sentinel pipeline
  # it's being tested against — only the Windows target is instrumented.
}

module "dcr_associations" {
  source = "../../modules/policy_dcr_association"

  # CHAINED OUTPUTS
  scope    = module.rg.id
  location = module.rg.location

  assignments = [
    {
      key             = "security-windows-attacklab"
      display_name    = "Associate Windows VMs with dcr_attacklab_windows_security"
      dcr_resource_id = module.dcr_attacklab_windows_security.dcr_id
      os_type         = "Windows"
    }
  ]

  depends_on = [module.policy_install_ama]
}
