terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "sa-east-1"

  assume_role {
    role_arn     = "arn:aws:iam::454634138220:role/TerraformExecutionRole"
    session_name = "TerraformLocalSession"
  }
}
