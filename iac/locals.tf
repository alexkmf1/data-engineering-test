locals {
  name_prefix = "${var.project_name}-${var.environment}"

  data_layers = toset([
    "landing",
    "bronze",
    "silver",
    "gold"
  ])

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}