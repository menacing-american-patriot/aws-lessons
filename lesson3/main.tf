terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source = "hashicorp/archive"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  endpoints {
    lambda = "http://localhost:4566"
    iam    = "http://localhost:4566"
  }
}

# 1. Zip the Python code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "hello.py"
  output_path = "payload.zip"
}

# 2. Create the Role
resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# 3. Create the Function
resource "aws_lambda_function" "test_lambda" {
  filename      = "payload.zip"
  function_name = "my-first-function"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "hello.lambda_handler"
  runtime       = "python3.9"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}
