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

variable "vnet_cidr" {
  type = string
}

variable "subnets" {
  type = map(number)
}