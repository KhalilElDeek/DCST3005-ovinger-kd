variable "base_name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "vm_size" {
  type = string

  validation {
    condition = contains([
      "Standard_B2als_v2", "Standard_B2as_v2", "Standard_B4als_v2", "Standard_B4as_v2",
      "Standard_D2s_v5", "Standard_D4s_v5", "Standard_D2s_v6", "Standard_D4s_v6",
      "Standard_E2s_v5", "Standard_E4s_v5", "Standard_E2s_v6", "Standard_E4s_v6"
    ], var.vm_size)
    error_message = "vm_size må være en av de godkjente SKU-ene i tenanten vår."
  }
}

variable "ssh_public_key" {
  type = string
}

variable "tags" {
  type = map(string)
}