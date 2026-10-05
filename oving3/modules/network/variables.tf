variable "rg_name" {
  description = "Name of the resource group (created at environment root, not here)"
  type        = string
}

variable "location" {
  type = string
}

variable "base_name" {
  description = "Composed base name delivered by the environment: project-environment-owner"
  type        = string
}

variable "vnet_cidr" {
  type = string
}

variable "subnets" {
  description = "Map of subnet name => netnum within vnet_cidr"
  type        = map(number)
}

variable "tags" {
  type = map(string)
}