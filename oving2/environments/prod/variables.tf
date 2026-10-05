# IDENTISK til dev/variables.tf
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "oving2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "norwayeast"
}

variable "owner" {
  description = "Owner identifier"
  type        = string
  default     = "kd"
}

variable "vnet_cidr" {
  description = "CIDR block for VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "vm_size" {
  description = "VM size"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
  # Note: Set this via terraform.tfvars or -var
}