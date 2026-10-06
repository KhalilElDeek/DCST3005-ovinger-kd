variable "owner" {
  description = "Ditt kortnavn, går inn i ressursgruppe- og storage account-navnet"
  type        = string
}

variable "location" {
  type    = string
  default = "norwayeast"
}

variable "pipeline_principal_id" {
  description = "Object-ID (ikke client-ID) til service principal-en workflowen logger inn som. az ad sp show --id <client-id> --query id -o tsv"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.pipeline_principal_id))
    error_message = "Skal være en GUID (object-ID), ikke client-ID."
  }
}
