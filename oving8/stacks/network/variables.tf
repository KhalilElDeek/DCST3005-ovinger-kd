variable "owner" {
  description = "Ditt kortnavn, går inn i alle ressursnavn."
  type        = string
}

variable "project_name" {
  description = "Prosjektnavn, del av navnegrunnlaget."
  type        = string
}

variable "environment" {
  description = "Miljønavn: dev, test eller prod. Kommer inn som en VERDI fra pipelinen, ikke som et mappenavn."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment må være dev, test eller prod i denne øvingen."
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