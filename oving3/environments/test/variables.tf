variable "subscription_id" {
  description = "Azure subscription ID. La stå null for å bruke aktiv az-subscription."
  type        = string
  default     = null
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "location" {
  type    = string
  default = "norwayeast"
}

variable "owner" {
  description = "Ditt kortnavn, for unike ressursnavn i delt tenant"
  type        = string
}

variable "vnet_cidr" {
  type = string
}

variable "subnets" {
  description = "Subnettnavn => netnum innenfor vnet_cidr"
  type        = map(number)
}

variable "vm_subnet_key" {
  description = "Hvilket subnet VM-en skal kobles til"
  type        = string
}

variable "vm_size" {
  type = string
}

variable "ssh_public_key" {
  type = string
}