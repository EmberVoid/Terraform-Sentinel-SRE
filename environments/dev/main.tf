## Provider and Terraform configuration
terraform {
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
module "dev_rg" {
  source  = "../../modules/resource_group"
  rg_name = "rg-dev-Sentinel-WUS3-01"
  location = "westus3"
  tags = {
    Environment = "Dev"
    ManagedBy   = "Terraform"
  }
}

## 2. Create the Networking infrastructure
module "dev_network" {
  source            = "../../modules/network"
  vnet_name         = "vnet-dev-Sentinel-WUS3-01"
  address_space     = ["10.123.0.0/16"]
  subnet_name       = "dev-subnet"
  subnet_prefix     = "10.123.1.0/24"
  client_ip         = var.client_ip
  
  # CHAINED OUTPUTS
  resource_group_name = module.dev_rg.name
  location            = module.dev_rg.location
}

## 3. Instantiate the Windows VM Module and chain the outputs
module "dev_win_vm" {
  source              = "../../modules/vm_windows"
  vm_name             = "WinSer1-VM-Dev"
  vm_size             = "Standard_B2als_v2"
  
  admin_username      = "sentineladmin"
  admin_password      = var.dev_win_vm_admin_password

  # CHAINED OUTPUTS
  # From dev_rg module
  resource_group_name = module.dev_rg.name
  location            = module.dev_rg.location

  # From dev_network Module
  subnet_id           = module.dev_network.subnet_id 
}

## 3.1. Instantiate the Ubuntu VM Module and chain the outputs
module "dev_ubuntu_vm" {
  source              = "../../modules/vm_ubuntu"
  vm_name             = "UbuDoc1-VM-Dev"
  vm_size             = "Standard_B2als_v2"
  
  admin_username      = "sendockadmin"
  pub_key             = var.pub_key

  # CHAINED OUTPUTS
  # From dev_rg module
  resource_group_name = module.dev_rg.name
  location            = module.dev_rg.location

  # From dev_network Module
  subnet_id           = module.dev_network.subnet_id 
}