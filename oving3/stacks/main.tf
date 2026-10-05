terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.7.0"
    }
  }
}

module "network" {
  source = "../modules/network"

  rg_name   = var.rg_name
  location  = var.location
  base_name = var.base_name
  vnet_cidr = var.vnet_cidr
  subnets   = var.subnets
  tags      = var.tags
}

module "compute" {
  source = "../modules/compute"

  base_name           = var.base_name
  location            = var.location
  resource_group_name = var.rg_name
  subnet_id           = module.network.subnet_ids[var.vm_subnet_key]
  vm_size             = var.vm_size
  ssh_public_key      = var.ssh_public_key
  tags                = var.tags
}