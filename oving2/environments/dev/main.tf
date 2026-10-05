terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.7.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "a3adf20e-4966-4afb-b717-4de1baae6db1"
}

resource "azurerm_resource_group" "main" {
  name     = lower(format("rg-%s-%s-%s", var.project_name, var.environment, var.owner))
  location = var.location
  tags     = local.common_tags
}

module "network" {
  source = "../../modules/network"

  project_name        = var.project_name
  environment         = var.environment
  owner               = var.owner
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  vnet_cidr           = var.vnet_cidr
  subnet_cidr         = var.subnet_cidr
  tags                = local.common_tags
}

module "compute" {
  source = "../../modules/compute"

  project_name        = var.project_name
  environment         = var.environment
  owner               = var.owner
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = module.network.subnet_id
  vm_size             = var.vm_size
  ssh_public_key      = var.ssh_public_key
  tags                = local.common_tags
}