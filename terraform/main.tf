# Configure the Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

# Create a Resource Group
resource "azurerm_resource_group" "sentinel_rg" {
  name     = "Sentinel-Ops-RG"
  location = var.location
}

# Create a Virtual Network (VNet)
resource "azurerm_virtual_network" "sentinel_vnet" {
  name                = "sentinel-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.sentinel_rg.location
  resource_group_name = azurerm_resource_group.sentinel_rg.name
}

# Create a Subnet
resource "azurerm_subnet" "sentinel_subnet" {
  name                 = "sentinel-subnet"
  resource_group_name  = azurerm_resource_group.sentinel_rg.name
  virtual_network_name = azurerm_virtual_network.sentinel_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create Network Security Group and rules
resource "azurerm_network_security_group" "sentinel_nsg" {
  name                = "sentinel-nsg"
  location            = azurerm_resource_group.sentinel_rg.location
  resource_group_name = azurerm_resource_group.sentinel_rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.ssh_source_address_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Grafana"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefixes    = var.ssh_source_address_prefix
    destination_address_prefix = "*"
  }
}

# Associate NSG with Subnet
resource "azurerm_subnet_network_security_group_association" "sentinel_nsg_assoc" {
  subnet_id                 = azurerm_subnet.sentinel_subnet.id
  network_security_group_id = azurerm_network_security_group.sentinel_nsg.id
}
# Create Public IP
resource "azurerm_public_ip" "sentinel_ip" {
  name                = "sentinel-public-ip"
  location            = azurerm_resource_group.sentinel_rg.location
  resource_group_name = azurerm_resource_group.sentinel_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create Network Interface (NIC)
resource "azurerm_network_interface" "sentinel_nic" {
  name                = "sentinel-nic"
  location            = azurerm_resource_group.sentinel_rg.location
  resource_group_name = azurerm_resource_group.sentinel_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.sentinel_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.sentinel_ip.id
  }
}

# Connect the NSG to the NIC
resource "azurerm_network_interface_security_group_association" "sentinel_nic_nsg" {
  network_interface_id      = azurerm_network_interface.sentinel_nic.id
  network_security_group_id = azurerm_network_security_group.sentinel_nsg.id
}

# Create the Ubuntu Virtual Machine
resource "azurerm_linux_virtual_machine" "sentinel_vm" {
  name                            = "sentinel-vm"
  resource_group_name             = azurerm_resource_group.sentinel_rg.name
  location                        = azurerm_resource_group.sentinel_rg.location
  size                            = var.vm_size
  admin_username                  = "sentineladmin"
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.sentinel_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}
output "public_ip_address" {
  value = azurerm_linux_virtual_machine.sentinel_vm.public_ip_address
}