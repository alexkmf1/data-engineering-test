variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "freighthero"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "int", "prod"], var.environment)
    error_message = "Environment must be dev, int, or prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "glue_version" {
  description = "AWS Glue runtime version used by the illustrative Spark jobs"
  type        = string
  default     = "5.1"
}

variable "glue_worker_type" {
  description = "Worker type used by the illustrative AWS Glue Spark jobs"
  type        = string
  default     = "G.1X"
}
