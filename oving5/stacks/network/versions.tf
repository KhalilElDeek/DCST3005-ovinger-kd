terraform {
  required_version = ">= 1.5.0"

  # K3: blokka er TOM, med vilje. Storage account-navnet skal ikke stå her -
  # det bor i shared/backend.hcl og sendes inn med -backend-config ved init.
  backend "azurerm" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.7.0"
    }
  }
}

provider "azurerm" {
  features {}
  # Ingen subscription_id her - jobben setter ARM_SUBSCRIPTION_ID via OIDC.
}
