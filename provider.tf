terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.58"
    }
  }
}

# -------- Minimal variables --------
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "aws_profile" {
  description = "Local AWS CLI profile (leave empty if using AWS_PROFILE env var or temporary credentials)"
  type        = string
  default     = ""
}

variable "env" {
  description = "Logical environment (dev/prod/sandbox-xxx)"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project name for default tags"
  type        = string
  default     = "aws-ec2-keypair-rotation"
}

# -------- AWS Provider --------
provider "aws" {
  region  = var.aws_region

  # Optional: force a local AWS CLI profile, otherwise leave empty and rely on $AWS_PROFILE
  profile = var.aws_profile != "" ? var.aws_profile : null

  default_tags {
    tags = {
      Project   = var.project
      Env       = var.env
      ManagedBy = "Terraform"
    }
  }
}
