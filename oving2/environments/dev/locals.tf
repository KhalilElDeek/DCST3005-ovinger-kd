locals {
  common_tags = {
    environment = var.environment
    owner       = var.owner
    managedby   = "Terraform"
    project     = var.project_name
  }
}