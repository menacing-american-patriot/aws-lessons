# main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# The Provider Block: This is where we trick Terraform
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  
  # Skip checks that only work on real AWS
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  # CRITICAL: Redirect all requests to your local server
  endpoints {
    s3             = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    iam            = "http://localhost:4566"
  }
}

# ---------------------------------------------------------
# The Lesson Resources
# ---------------------------------------------------------

# 1. Create a Bucket (Storage)
resource "aws_s3_bucket" "class_bucket" {
  bucket = "terraform-is-cool"
}

# 2. Create a Database Table
resource "aws_dynamodb_table" "class_db" {
  name           = "StudentGrades"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "StudentID"

  attribute {
    name = "StudentID"
    type = "S"
  }
}
