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

  common_tags = {
    environment = var.environment
    owner       = var.owner
    project     = var.project_name
    managedby   = "terraform"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = format("rg-%s", local.base_name)
  location = var.location
  tags     = local.common_tags
}

module "stack" {
  source = "../../stacks"

  rg_name       = azurerm_resource_group.rg.name
  location      = var.location
  base_name     = local.base_name
  tags          = local.common_tags

  vnet_cidr     = var.vnet_cidr
  subnets       = var.subnets
  vm_subnet_key = var.vm_subnet_key

  vm_size        = var.vm_size
  ssh_public_key = var.ssh_public_key
}