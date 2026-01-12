terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive" }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true
  endpoints {
    s3     = "http://192.168.67.2:31566"
    lambda = "http://192.168.67.2:31566"
    iam    = "http://192.168.67.2:31566"
    sts    = "http://192.168.67.2:31566"
  }
}

# 1. The Bucket
resource "aws_s3_bucket" "upload_bucket" {
  bucket = "project-bucket"
}

# 2. The Lambda (Zip & Deploy)
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "processor.py"
  output_path = "payload.zip"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda_trigger"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_lambda_function" "processor" {
  filename      = "payload.zip"
  function_name = "file-processor"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "processor.lambda_handler"
  runtime       = "python3.9"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# 3. The Permission (Allow S3 to call Lambda)
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.upload_bucket.arn
}

# 4. The Trigger (Tell S3 to notify Lambda on upload)
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.upload_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
  }
  
  depends_on = [aws_lambda_permission.allow_s3]
}
