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
  s3_use_path_style           = true
  endpoints {
    s3         = "http://192.168.67.2:31566"
    lambda     = "http://192.168.67.2:31566"
    iam        = "http://192.168.67.2:31566"
    sts        = "http://192.168.67.2:31566"
    dynamodb   = "http://192.168.67.2:31566"
    apigateway = "http://192.168.67.2:31566"
  }
}

# 1. DynamoDB Table
resource "aws_dynamodb_table" "notes_table" {
  name           = "Notes"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "noteId"

  attribute {
    name = "noteId"
    type = "S"
  }
}

# 2. Lambda Function and Role
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "database_handler.py"
  output_path = "payload.zip"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda_db"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "lambda_dynamodb_policy"
  role = aws_iam_role.iam_for_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem"
      ]
      Effect   = "Allow"
      Resource = aws_dynamodb_table.notes_table.arn
    }]
  })
}

resource "aws_lambda_function" "db_lambda" {
  filename         = "payload.zip"
  function_name    = "database-handler-function"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "database_handler.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.notes_table.name
    }
  }
}

# 3. API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name        = "NotesAPI"
  description = "An API for creating and retrieving notes"
}

resource "aws_api_gateway_resource" "notes_resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "notes"
}

resource "aws_api_gateway_method" "post_notes_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.notes_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_notes_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.notes_resource.id
  http_method = aws_api_gateway_method.post_notes_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.db_lambda.invoke_arn
}

resource "aws_api_gateway_resource" "note_item_resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.notes_resource.id
  path_part   = "{noteId}"
}

resource "aws_api_gateway_method" "get_note_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.note_item_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_note_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.note_item_resource.id
  http_method = aws_api_gateway_method.get_note_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.db_lambda.invoke_arn
}

# 4. Deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "dev"

  depends_on = [
    aws_api_gateway_integration.post_notes_integration,
    aws_api_gateway_integration.get_note_integration,
  ]
}

# 5. Permissions
resource "aws_lambda_permission" "allow_apigateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.db_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# 6. Output
output "api_endpoint" {
  description = "The URL of the API endpoint"
  value       = "${aws_api_gateway_deployment.api_deployment.invoke_url}"
}
