locals {
  name_prefix = "${var.project_name}-${var.environment}-${var.owner}"

  tags = {
    Owner       = var.owner
    Project     = var.project_name
    CostCenter  = var.cost_center
    Environment = var.environment
  }
}