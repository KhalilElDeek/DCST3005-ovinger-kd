variable "owner" {
  description = "Ditt kortnavn, går inn i ressursgruppe- og storage account-navnet"
  type        = string
}

variable "location" {
  type    = string
  default = "norwayeast"
}

variable "subscription_id" {
  type    = string
  default = null
}