variable "rg_name" {
  type = string
}

variable "location" {
  type = string
}

variable "base_name" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "vnet_cidr" {
  type = string
}

variable "subnets" {
  type = map(number)
}

variable "vm_subnet_key" {
  description = "Which subnet key the VM's NIC should attach to"
  type        = string
}

variable "vm_size" {
  type = string
}

variable "ssh_public_key" {
  type = string
}