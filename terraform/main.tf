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
  resource_provider_registrations = "none"
}

# Create a Resource Group
resource "azurerm_resource_group" "sentinel_rg" {
  name     = "Sentinel-Ops-RG"
  location = "East US"
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