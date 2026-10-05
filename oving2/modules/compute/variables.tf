variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet"
  type        = string
}

variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string

  validation {
    condition     = contains(["Standard_B2als_v2", "Standard_B2as_v2", "Standard_B4als_v2", "Standard_B4as_v2", "Standard_D2s_v5", "Standard_D4s_v5"], var.vm_size)
    error_message = "VM size must be one of the approved SKUs"
  }
}

variable "ssh_public_key" {
  description = "SSH public key for admin access"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "owner" {
  description = "Owner identifier for unique naming"
  type        = string
  default     = "kd"
}