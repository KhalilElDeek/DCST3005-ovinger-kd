terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.7.0"
    }
  }
}

resource "azurerm_virtual_network" "main" {
  name                = lower(format("vnet-%s-%s-%s", var.project_name, var.environment, var.owner))
  address_space       = [var.vnet_cidr]
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_subnet" "main" {
  name                 = lower(format("subnet-%s-%s-%s", var.project_name, var.environment, var.owner))
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidr]
}