# ---------------------------------------------------------
# Windows Jumpbox – snet-mgmt (hub VNet)
#
# Accessible via RDP (3389) through an Azure Firewall DNAT
# rule — see firewall_rules.tf "nrc-jumpbox-rdp".
# Direct inbound to the NIC is blocked by the NSG; all RDP
# traffic must arrive via the firewall public IP.
# ---------------------------------------------------------

# NSG – deny all direct inbound (firewall is the only ingress path)
resource "azurerm_network_security_group" "jumpbox" {
  name                = "nsg-jumpbox"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
}

resource "azurerm_subnet_network_security_group_association" "mgmt" {
  subnet_id                 = azurerm_subnet.mgmt.id
  network_security_group_id = azurerm_network_security_group.jumpbox.id
}

# Public IP – used by the DNAT rule as a destination address in 
# the firewall policy. NOT attached to the VM directly.
# (VM has no public IP — private only.)

# NIC – private IP only in snet-mgmt
resource "azurerm_network_interface" "jumpbox" {
  name                = "nic-jumpbox-01"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.mgmt.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Windows Server VM
resource "azurerm_windows_virtual_machine" "jumpbox" {
  name                = var.jumpbox_vm_name
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  size                = "Standard_B2ms"
  admin_username      = var.jumpbox_admin_username
  admin_password      = var.jumpbox_admin_password

  network_interface_ids = [azurerm_network_interface.jumpbox.id]

  os_disk {
    name                 = "osdisk-jumpbox-01"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-azure-edition"
    version   = "latest"
  }

  # Disable public IP on the VM — RDP only via firewall DNAT
  patch_mode            = "AutomaticByOS"
  enable_automatic_updates = true

  tags = {
    purpose = "jumpbox"
  }
}
