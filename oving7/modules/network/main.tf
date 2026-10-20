terraform {
  required_version = ">= 1.5.0"

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

# Ingen inbound-regler fra internett: ingenting i denne stacken trenger det
# ennå. Azure NSG-er denyer alt inbound som standard når ingen regel tillater
# det - en tom NSG her er derfor et bevisst, sikkert utgangspunkt, ikke en
# forglemmelse.
resource "azurerm_network_security_group" "main" {
  name                = lower(format("nsg-%s", var.base_name))
  location            = var.location
  resource_group_name = var.rg_name

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "main" {
  for_each = azurerm_subnet.main

  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.main.id
}
