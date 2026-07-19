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
  resource_provider_registrations = "none"              # This is only required when the User, Service Principal, or Identity running Terraform lacks the permissions to register Azure Resource Providers.
  subscription_id                 = var.subscription_id # Required when running Terraform Plan
  features {}
}

## 1. Instantiate the Resource Group Module
module "rg" {
  source   = "../../modules/resource_group"
  rg_name  = var.rg_name
  location = "westus3"
  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

## 2. Create the Networking infrastructure
module "network" {
  source        = "../../modules/network"
  vnet_name     = var.vnet_name
  address_space = ["10.123.0.0/16"]
  subnet_name   = var.subnet_name
  subnet_prefix = "10.123.1.0/24"
  client_ip     = var.client_ip

  # CHAINED OUTPUTS
  resource_group_name = module.rg.name
  location            = module.rg.location
}

## 3. Instantiate the Windows VM Module and chain the outputs
module "WinSer1_VM" {
  source  = "../../modules/vm_windows"
  vm_name = "WinSer1_VM"
  vm_size = "Standard_B2als_v2"

  admin_username = "sentineladmin"
  admin_password = var.WinSer1_VM_admin_password

  # CHAINED OUTPUTS
  # From rg module
  resource_group_name = module.rg.name
  location            = module.rg.location

  # From network Module
  subnet_id = module.network.subnet_id
}

## 3.1. Instantiate the Ubuntu VM Module and chain the outputs
module "UbuDoc1_VM" {
  source  = "../../modules/vm_ubuntu"
  vm_name = "UbuDoc1_VM"
  vm_size = "Standard_B2als_v2"

  admin_username = "sendockadmin"
  pub_key        = var.pub_key

  # CHAINED OUTPUTS
  # From rg module
  resource_group_name = module.rg.name
  location            = module.rg.location

  # From network Module
  subnet_id = module.network.subnet_id
}

output "Public_IP_WinSer1_VM_" {
  value = "${module.WinSer1_VM.vm_id} : ${module.WinSer1_VM.public_ip}"
}

output "Public_IP_UbuDoc1_VM_" {
  value = "${module.UbuDoc1_VM.vm_id} : ${module.UbuDoc1_VM.public_ip}"
}

## 4. Deploy the Log Analytics Workspace
module "law" {
  source   = "../../modules/log_analytics"
  law_name = "law--Sentinel-WUS3"

  # CHAINED OUTPUTS
  resource_group_name = module.rg.name
  location            = module.rg.location
}

## 5. Deploy Sentinel and configure the Activity Log to stream to the Log Analytics Workspace
module "sentinel" {
  source          = "../../modules/sentinel"
  subscription_id = var.subscription_id

  # CHAINED OUTPUTS
  law_id   = module.law.law_id
  location = module.rg.location
}

## 6. Deploy the DCRs for Sentinel data connectors
## 6.1. Standard data connector - Windows and Linux performance counters
module "dcr_all_os_vm_perf" {
  source = "../../modules/dcr"

  name        = "dcr_all_os_vm_perf"
  kind        = null
  description = "Standard performance counters for Windows and Linux machines"

  # CHAINED OUTPUTS
  resource_group_name = module.rg.name
  location            = module.rg.location
  law_id              = module.law.law_id

  data_flows = [
    {
      streams = ["Microsoft-Perf"]
    }
  ]

  performance_counters = [
    {
      name                          = "allOSVMPerf"
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers            = var.counter_specifiers
    }
  ]
}

## 6.2 Sentinel data connector - Windows Security Events
module "dcr_sentinel_windows_security" {
  source = "../../modules/dcr"

  name        = "dcr_sentinel_windows_security"
  kind        = "Windows"
  description = "Sentinel: Windows Security Events via AMA"

  # CHAINED OUTPUTS
  resource_group_name = module.rg.name
  location            = module.rg.location
  law_id              = module.law.law_id

  data_flows = [
    {
      streams       = ["Microsoft-SecurityEvent"]
      output_stream = "Microsoft-SecurityEvent"
      # Optional example transform - drop noisy event IDs at ingestion:
      # transform_kql = "source | where EventID != 4688"
    }
  ]

  windows_event_logs = [
    {
      name           = "WindowsSecurityEvents"
      streams        = ["Microsoft-SecurityEvent"]
      x_path_queries = var.windows_security_xpath_queries
    }
  ]
}

## 6.3 Sentinel data connector - Syslog
module "dcr_sentinel_syslog_cef" {
  source = "../../modules/dcr"

  name        = "dcr_sentinel_syslog_cef"
  kind        = "Linux"
  description = "Sentinel: Syslog/CEF via AMA"

  # CHAINED OUTPUTS
  resource_group_name = module.rg.name
  location            = module.rg.location
  law_id              = module.law.law_id

  data_flows = [
    {
      streams = ["Microsoft-Syslog"]
    },
    {
      streams = ["Microsoft-CommonSecurityLog"]
    }
  ]

  syslog_sources = [
    {
      name           = "syslogDataSource"
      streams        = ["Microsoft-Syslog"]
      facility_names = var.syslog_facilities
      log_levels     = var.syslog_log_levels
    },
    {
      name           = "cefDataSource"
      streams        = ["Microsoft-CommonSecurityLog"]
      facility_names = var.cef_facilities
      log_levels     = var.cef_log_levels
    }
  ]
}

## 7. Deploy the Policy Assignment for auto-associating DCRs to VMs
module "policy_install_ama" {
  source = "../../modules/policy_install_ama"

  # CHAINED OUTPUTS
  scope    = module.rg.id
  location = module.rg.location
}

module "dcr_associations" {
  source = "../../modules/policy_dcr_association"

  # CHAINED OUTPUTS
  scope    = module.rg.id
  location = module.rg.location

  assignments = [
    {
      key             = "perf-linux"
      display_name    = "Associate Linux VMs with dcr_all_os_vm_perf"
      dcr_resource_id = module.dcr_all_os_vm_perf.dcr_id
      os_type         = "Linux"
    },
    {
      key             = "perf-windows"
      display_name    = "Associate Windows VMs with dcr_all_os_vm_perf"
      dcr_resource_id = module.dcr_all_os_vm_perf.dcr_id
      os_type         = "Windows"
    },
    {
      key             = "security-windows"
      display_name    = "Associate Windows VMs with dcr_sentinel_windows_security"
      dcr_resource_id = module.dcr_sentinel_windows_security.dcr_id
      os_type         = "Windows"
    },
    {
      key             = "syslog-linux"
      display_name    = "Associate Linux VMs with dcr_sentinel_syslog_cef"
      dcr_resource_id = module.dcr_sentinel_syslog_cef.dcr_id
      os_type         = "Linux"
    }
  ]

  depends_on = [module.policy_install_ama]
}
#