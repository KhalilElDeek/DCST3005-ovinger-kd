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

data "terraform_remote_state" "network" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = var.network_state_key
    use_azuread_auth     = true
  }
}

locals {
  base_name = lower(format("%s-%s-%s", var.project_name, var.environment, var.owner))

  tags = {
    environment = var.environment
    owner       = var.owner
    project     = var.project_name
    stack       = "app"
    managedby   = "terraform"
  }

  subnet_id = data.terraform_remote_state.network.outputs.subnet_ids[var.vm_subnet_key]
}

resource "azurerm_resource_group" "rg" {
  name     = format("rg-app-%s", local.base_name)
  location = var.location
  tags     = local.tags
}

module "compute" {
  source = "../../../modules/compute"

  rg_name        = azurerm_resource_group.rg.name
  location       = var.location
  base_name      = local.base_name
  subnet_id      = local.subnet_id
  vm_size        = var.vm_size
  ssh_public_key = var.ssh_public_key
  tags           = local.tags
}