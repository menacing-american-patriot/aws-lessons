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
    apigateway = "http://192.168.67.2:31566"
  }
}

# 1. The Lambda Function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "api_handler.py"
  output_path = "payload.zip"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda_api"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_lambda_function" "api_lambda" {
  filename         = "payload.zip"
  function_name    = "api-handler-function"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "api_handler.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# 2. The API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name        = "MyAPI"
  description = "An API for the lesson"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_method.proxy_method.resource_id
  http_method = aws_api_gateway_method.proxy_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_lambda.invoke_arn
}

# 3. Deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "dev"

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.proxy.id,
      aws_api_gateway_method.proxy_method.id,
      aws_api_gateway_integration.lambda_integration.id,
    ]))
  }

  depends_on = [aws_api_gateway_method.proxy_method, aws_api_gateway_integration.lambda_integration]
}

# 4. Permissions
resource "aws_lambda_permission" "allow_apigateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# 5. Output
output "api_endpoint" {
  description = "The URL of the API endpoint"
  value       = "${aws_api_gateway_deployment.api_deployment.invoke_url}/"
}
