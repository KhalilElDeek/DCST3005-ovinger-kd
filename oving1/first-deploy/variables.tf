variable "location" {
  description = "The  region to deploy resources"
  type        = string
  default     = "norwayeast"
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "demo"
}

variable "owner" {
  description = "The owner of the project"
  type        = string
  default     = "kd"
}

variable "environment" {
  description = "The environment for the deployment"
  type        = string
  default     = "dev"
}

variable "cost_center" {
  description = "The cost center for the project"
  type        = string
  default     = "demo"
}