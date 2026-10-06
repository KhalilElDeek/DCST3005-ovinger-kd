variable "owner" {
  description = "Ditt eget kortnavn. Går inn i alle ressursnavn."
  type        = string
}

variable "project_name" {
  description = "Prosjektnavn, del av navnegrunnlaget."
  type        = string
}

variable "environment" {
  description = "Miljønavn: dev eller test. Kommer inn som en VERDI fra pipelinen, ikke som et mappenavn (K6)."
  type        = string

  validation {
    condition     = contains(["dev", "test"], var.environment)
    error_message = "environment må være dev eller test i denne øvingen."
  }
}

variable "location" {
  description = "Azure-regionen ressursene opprettes i."
  type        = string
  default     = "norwayeast"
}

variable "vnet_cidr" {
  description = "Adresserommet dette miljøet disponerer, som CIDR."
  type        = string
}

variable "subnets" {
  description = "Subnett som skal opprettes: navn => netnum innenfor adresserommet."
  type        = map(number)
}
