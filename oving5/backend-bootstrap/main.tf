terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # K1 (modul 4): INGEN backend-blokk her, med vilje. Denne stacken oppretter
  # stedet alle andre stacks lagrer state i, og kan ikke lagre sin egen state
  # der før det finnes (hønen og egget). Lokal state er akseptabelt akkurat
  # for DENNE stacken fordi den bare har noen få ressurser - mister du den,
  # importerer du dem tilbake med terraform import på et kvarter.
}

provider "azurerm" {
  features {}
  storage_use_azuread = true
}

data "azurerm_client_config" "current" {}

resource "random_string" "storage_suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

locals {
  tags = {
    keep      = "true"
    purpose   = "terraform-backend"
    owner     = var.owner
    managedby = "terraform"
  }

  sa_name = substr(lower("sttf${var.owner}${random_string.storage_suffix.result}"), 0, 24)
}

resource "azurerm_resource_group" "tfstate" {
  name     = format("rg-tfstate-%s", var.owner)
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "tfstate" {
  name                = local.sa_name
  resource_group_name = azurerm_resource_group.tfstate.name
  location            = azurerm_resource_group.tfstate.location

  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = "LRS"

  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  tags = local.tags
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# Deg selv - til å feilsøke og bootstrappe fra din egen maskin.
resource "azurerm_role_assignment" "meg_blob_contributor" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "User"
}
