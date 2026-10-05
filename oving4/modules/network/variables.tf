variable "rg_name" {
  description = "Resource group networket skal ligge i (opprettes av stacken, ikke her)"
  type        = string
}

variable "location" {
  type = string
}

variable "base_name" {
  description = "Navnegrunnlag levert av miljøet: project-environment-owner"
  type        = string
}

variable "vnet_cidr" {
  type = string
  validation {
    condition     = can(cidrhost(var.vnet_cidr, 0))
    error_message = "vnet_cidr må være en gyldig CIDR, f.eks. 10.10.0.0/16."
  }
}

variable "subnets" {
  description = "Subnettnavn => netnum innenfor vnet_cidr"
  type        = map(number)
}

variable "tags" {
  type    = map(string)
  default = {}
}