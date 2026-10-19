terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.7.0"
    }
  }
}

resource "azurerm_virtual_network" "main" {
  name                = lower(format("vnet-%s", var.base_name))
  address_space       = [var.vnet_cidr]
  location            = var.location
  resource_group_name = var.rg_name

  tags = var.tags
}

resource "azurerm_subnet" "main" {
  for_each = var.subnets

  name                 = lower(format("snet-%s-%s", var.base_name, each.key))
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, each.value)]
}

resource "azurerm_network_security_group" "main" {
  name                = lower(format("nsg-%s", var.base_name))
  location            = var.location
  resource_group_name = var.rg_name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "main" {
  for_each = azurerm_subnet.main

  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.main.id
}
