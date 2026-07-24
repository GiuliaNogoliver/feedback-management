terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "feedback-management-tfstate-454634138220"
    key            = "terraform.tfstate"
    region         = "sa-east-1"
    dynamodb_table = "feedback-management-tfstate-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "sa-east-1"

  assume_role {
    role_arn     = "arn:aws:iam::454634138220:role/TerraformExecutionRole"
    session_name = "TerraformLocalSession"
  }
}
