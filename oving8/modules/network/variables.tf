variable "rg_name" {
  description = "Resource group networket skal ligge i (opprettes av stacken, ikke her)"
  type        = string
}

variable "location" {
  description = "Azure-regionen ressursene opprettes i."
  type        = string
}

variable "base_name" {
  description = "Navnegrunnlaget levert av stacken, f.eks. 'oving5-dev-kd'. Modulen setter selv på prefiksene vnet-, snet- og nsg-."
  type        = string
}

variable "vnet_cidr" {
  description = "Adresserommet vnet-et disponerer, som CIDR, f.eks. 10.10.0.0/16."
  type        = string

  validation {
    condition     = can(cidrhost(var.vnet_cidr, 0))
    error_message = "vnet_cidr må være en gyldig CIDR-blokk, f.eks. 10.10.0.0/16."
  }
}

variable "subnets" {
  description = "Subnett som skal opprettes: navn => netnum innenfor adresserommet."
  type        = map(number)
}

variable "tags" {
  description = "Felles tags fra stacken. Tags arves ikke fra ressursgruppa i Azure."
  type        = map(string)
  default     = {}
}
