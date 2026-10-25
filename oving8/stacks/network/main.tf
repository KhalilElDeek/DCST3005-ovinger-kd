# K4: navnet bygges HER, i locals, fra variabler - og følger samme
# konvensjon som resten av øvingene (project-environment-owner).
locals {
  base_name = lower(format("%s-%s-%s", var.project_name, var.environment, var.owner))

  tags = {
    environment = var.environment
    owner       = var.owner
    project     = var.project_name
    stack       = "network"
    managedby   = "terraform"
    kurs        = "dcst3005"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = format("rg-nett-%s", local.base_name)
  location = var.location
  tags     = local.tags
}

module "nett" {
  source = "../../modules/network"

  rg_name   = azurerm_resource_group.rg.name
  location  = var.location
  base_name = local.base_name
  vnet_cidr = var.vnet_cidr
  subnets   = var.subnets
  tags      = local.tags
}
# trigger K8/K9-sjekk
