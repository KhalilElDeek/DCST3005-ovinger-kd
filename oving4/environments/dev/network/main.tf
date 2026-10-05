terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.7.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

locals {
  base_name = lower(format("%s-%s-%s", var.project_name, var.environment, var.owner))

  tags = {
    environment = var.environment
    owner       = var.owner
    project     = var.project_name
    stack       = "network"
    managedby   = "terraform"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = format("rg-nett-%s", local.base_name)
  location = var.location
  tags     = local.tags
}

module "network" {
  source = "../../../modules/network"

  rg_name   = azurerm_resource_group.rg.name
  location  = var.location
  base_name = local.base_name
  vnet_cidr = var.vnet_cidr
  subnets   = var.subnets
  tags      = local.tags
}