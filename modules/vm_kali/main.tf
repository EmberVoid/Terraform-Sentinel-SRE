# 1. Accept the Kali Linux marketplace legal terms (one-time per subscription
#    for this publisher/offer/plan combo). NOTE: on a destroy/recreate of this
#    environment, Terraform may try to recreate this resource even though the
#    agreement still exists in Azure — if so, import it instead of re-applying:
#    terraform import azurerm_marketplace_agreement.kali kali-linux/kali/<plan>
resource "azurerm_marketplace_agreement" "kali" {
  publisher = "kali-linux"
  offer     = "kali"
  plan      = var.kali_version
}

# 2. Public IP for the VM
resource "azurerm_public_ip" "pip" {
  name                = "${var.vm_name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Basic"
  allocation_method   = "Static"
}

# 3. Network Interface Card
resource "azurerm_network_interface" "nic" {
  name                = "${var.vm_name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

# 4. The Kali Linux VM (official kali-linux marketplace image, SSH key auth only)
resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.pub_key
  }

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "kali-linux"
    offer     = "kali"
    sku       = var.kali_version
    version   = "latest"
  }

  # Required alongside source_image_reference for marketplace (non-default) images,
  # or the deploy fails with a plan-mismatch error.
  plan {
    name      = var.kali_version
    publisher = "kali-linux"
    product   = "kali"
  }

  depends_on = [azurerm_marketplace_agreement.kali]
}
