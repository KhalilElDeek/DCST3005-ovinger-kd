variable "subscription_id" {
  type    = string
  default = null
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
  type = string
}

variable "vm_size" {
  type = string
}

variable "vm_subnet_key" {
  description = "Hvilket subnett (som navn) VM-en skal på — slått opp i networks-stackens outputs"
  type        = string
}

variable "ssh_public_key" {
  type = string
}

variable "backend_resource_group_name" {
  type = string
}

variable "backend_storage_account_name" {
  type = string
}

variable "backend_container_name" {
  type    = string
  default = "tfstate"
}

variable "network_state_key" {
  description = "key til networks-stackens state, f.eks. dev/network.tfstate"
  type        = string
}