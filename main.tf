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

### Resource Deployment

## Resource Group
resource "azurerm_resource_group" "Terra_Sentinel-WUS3-Dev-RG" {
  name     = "Sentinel-WUS3-Dev-RG"
  location = "westus3"

  tags = {
    environment = "Dev"
    deployer    = "Terraform"
  }
}

## Virtual Network
resource "azurerm_virtual_network" "Terra_VM-Dev-VNet" {
  name                = "VM-Dev-VNet"
  resource_group_name = azurerm_resource_group.Terra_Sentinel-WUS3-Dev-RG.name
  location            = azurerm_resource_group.Terra_Sentinel-WUS3-Dev-RG.location
  address_space       = ["10.123.0.0/16"]

  tags = {
    environment = "Dev"
    deployer    = "Terraform"
  }
}

resource "azurerm_subnet" "Terra_VM-Dev-VNet-subnet1" {
  name                 = "VM-Dev-VNet-subnet1"
  resource_group_name  = azurerm_resource_group.Terra_Sentinel-WUS3-Dev-RG.name
  virtual_network_name = azurerm_virtual_network.Terra_VM-Dev-VNet.name
  address_prefixes     = ["10.123.1.0/24"]
}

## Public IP
resource "azurerm_public_ip" "Terra_WinSer1-VM-Dev-PublicIP" {
  name                = "WinSer1-VM-Dev-PublicIP"
  resource_group_name = azurerm_resource_group.Terra_Sentinel-WUS3-Dev-RG.name
  location            = azurerm_resource_group.Terra_Sentinel-WUS3-Dev-RG.location
  sku                 = "Basic"
  allocation_method   = "Dynamic"

  tags = {
    environment = "Dev"
    deployer    = "Terraform"
  }
}

resource "azurerm_public_ip" "Terra_UbuDoc1-VM-Dev-PublicIP" {
  name                = "UbuDoc1-VM-Dev-PublicIP"
  resource_group_name = azurerm_resource_group.Terra_Sentinel-WUS3-Dev-RG.name
  location            = azurerm_resource_group.Terra_Sentinel-WUS3-Dev-RG.location
  sku                 = "Basic"
  allocation_method   = "Dynamic"

  tags = {
    environment = "Dev"
    deployer    = "Terraform"
  }
}

## Network Interface
resource "azurerm_network_interface" "Terra_WinSer1-VM-Dev-NIC" {
  name                = "WinSer1-VM-Dev-NIC"
  resource_group_name = azurerm_resource_group.Terra_Sentinel-WUS3-Dev-RG.name
  location            = azurerm_resource_group.Terra_Sentinel-WUS3-Dev-RG.location

  ip_configuration {
    name                          = "WinSer1-VM-Dev-NIC-IPConfig"
    subnet_id                     = azurerm_subnet.Terra_VM-Dev-VNet-subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.Terra_WinSer1-VM-Dev-PublicIP.id
  }

  tags = {
    environment = "Dev"
    deployer    = "Terraform"
  }
}

resource "azurerm_network_interface" "Terra_UbuDoc1-VM-Dev-NIC" {
  name                = "UbuDoc1-VM-Dev-NIC"
  resource_group_name = azurerm_resource_group.Terra_Sentinel-WUS3-Dev-RG.name
  location            = azurerm_resource_group.Terra_Sentinel-WUS3-Dev-RG.location

  ip_configuration {
    name                          = "UbuDoc1-VM-Dev-NIC-IPConfig"
    subnet_id                     = azurerm_subnet.Terra_VM-Dev-VNet-subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.Terra_UbuDoc1-VM-Dev-PublicIP.id
  }

  tags = {
    environment = "Dev"
    deployer    = "Terraform"
  }
}

## Security Group
resource "azurerm_network_security_group" "Terra_VM-Dev-NSG" {
  name                = "VM-Dev-NSG"
  resource_group_name = azurerm_resource_group.Terra_Sentinel-WUS3-Dev-RG.name
  location            = azurerm_resource_group.Terra_Sentinel-WUS3-Dev-RG.location

  tags = {
    environment = "Dev"
    deployer    = "Terraform"
  }
}

resource "azurerm_network_security_rule" "Terra_VM-Dev-NSG-Rule" {
  name                        = "VM-Dev-NSG-Rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = var.client_IP
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.Terra_Sentinel-WUS3-Dev-RG.name
  network_security_group_name = azurerm_network_security_group.Terra_VM-Dev-NSG.name
}

resource "azurerm_subnet_network_security_group_association" "Terra_VM-Dev-NSG-Association" {
  subnet_id                 = azurerm_subnet.Terra_VM-Dev-VNet-subnet1.id
  network_security_group_id = azurerm_network_security_group.Terra_VM-Dev-NSG.id
}

## Virtual Machines
resource "azurerm_windows_virtual_machine" "Terra_WinSer1-VM-Dev" {
  name                = "WinSer1-VM-Dev"
  resource_group_name = azurerm_resource_group.Terra_Sentinel-WUS3-Dev-RG.name
  location            = azurerm_resource_group.Terra_Sentinel-WUS3-Dev-RG.location
  size                = "Standard_B2als_v2"
  admin_username      = "sentineladmin"
  admin_password      = var.winser1_vm_dev_admin_password
  network_interface_ids = [
    azurerm_network_interface.Terra_WinSer1-VM-Dev-NIC.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition-smalldisk"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "Terra_UbuDoc1-VM-Dev" {
  name                = "UbuDoc1-VM-Dev"
  resource_group_name = azurerm_resource_group.Terra_Sentinel-WUS3-Dev-RG.name
  location            = azurerm_resource_group.Terra_Sentinel-WUS3-Dev-RG.location
  size                = "Standard_B2als_v2"
  admin_username      = "sendockadmin"
  network_interface_ids = [
    azurerm_network_interface.Terra_UbuDoc1-VM-Dev-NIC.id,
  ]

  admin_ssh_key {
    username   = "sendockadmin"
    public_key = var.pub_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

#Possible update later to iterate through a list of VMs to create multiple VMs with the same configuration but different names and IPs and share in the output section. 
#The output section will then iterate through the list of VMs and output their names and IPs.
output "Public_IP_WinSer1_VM_Dev" {
  value = "${azurerm_windows_virtual_machine.Terra_WinSer1-VM-Dev.name}:${azurerm_public_ip.Terra_WinSer1-VM-Dev-PublicIP.ip_address}"
}

output "Public_IP_UbuDoc1_VM_Dev" {
  value = "${azurerm_linux_virtual_machine.Terra_UbuDoc1-VM-Dev.name}:${azurerm_public_ip.Terra_UbuDoc1-VM-Dev-PublicIP.ip_address}"
}
