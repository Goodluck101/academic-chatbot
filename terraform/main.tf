terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    # These will be set from environment variables or .env file
    bucket = "academic-chatbot-tf-state"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

# Load environment variables from .env file if it exists
locals {
  env_vars = {
    aws_region        = try(var.aws_region, "us-east-1")
    project_name      = try(var.project_name, "academic-chatbot")
    environment       = try(var.environment, "dev")
    bedrock_model_id  = try(var.bedrock_model_id, "anthropic.claude-3-haiku-20240307-v1:0")
    max_tokens        = try(var.max_tokens, 1000)
    temperature       = try(var.temperature, 0.5)
    lambda_timeout    = try(var.lambda_timeout, 30)
    lambda_memory_size = try(var.lambda_memory_size, 128)
    lambda_runtime    = try(var.lambda_runtime, "python3.9")
    allowed_origins   = try(var.allowed_origins, "*")
  }
}

provider "aws" {
  region = local.env_vars.aws_region
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${local.env_vars.project_name}-${local.env_vars.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Project     = local.env_vars.project_name
    Environment = local.env_vars.environment
  }
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${local.env_vars.project_name}-${local.env_vars.environment}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "chatbot_lambda" {
  filename         = "../backend/lambda_function.zip"
  function_name    = "${local.env_vars.project_name}-${local.env_vars.environment}-function"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = local.env_vars.lambda_runtime
  timeout         = local.env_vars.lambda_timeout
  memory_size     = local.env_vars.lambda_memory_size

  environment {
    variables = {
      AWS_REGION        = local.env_vars.aws_region
      BEDROCK_MODEL_ID  = local.env_vars.bedrock_model_id
      MAX_TOKENS        = local.env_vars.max_tokens
      TEMPERATURE       = local.env_vars.temperature
      ALLOWED_ORIGINS   = local.env_vars.allowed_origins
      ENVIRONMENT       = local.env_vars.environment
      PROJECT_NAME      = local.env_vars.project_name
    }
  }

  tags = {
    Project     = local.env_vars.project_name
    Environment = local.env_vars.environment
  }

  depends_on = [aws_iam_role_policy.lambda_policy]
}

# API Gateway
resource "aws_apigatewayv2_api" "chatbot_api" {
  name          = "${local.env_vars.project_name}-${local.env_vars.environment}-api"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins = [local.env_vars.allowed_origins]
    allow_methods = ["POST", "OPTIONS", "GET"]
    allow_headers = ["content-type", "authorization"]
    max_age       = 300
  }

  tags = {
    Project     = local.env_vars.project_name
    Environment = local.env_vars.environment
  }
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.chatbot_api.id
  name        = local.env_vars.environment
  auto_deploy = true

  tags = {
    Project     = local.env_vars.project_name
    Environment = local.env_vars.environment
  }
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.chatbot_api.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.chatbot_lambda.invoke_arn
}

# API Gateway Route
resource "aws_apigatewayv2_route" "chat_route" {
  api_id    = aws_apigatewayv2_api.chatbot_api.id
  route_key = "POST /chat"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# API Gateway Route for OPTIONS (CORS)
resource "aws_apigatewayv2_route" "options_route" {
  api_id    = aws_apigatewayv2_api.chatbot_api.id
  route_key = "OPTIONS /chat"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chatbot_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.chatbot_api.execution_arn}/*/*"
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.chatbot_lambda.function_name}"
  retention_in_days = 7

  tags = {
    Project     = local.env_vars.project_name
    Environment = local.env_vars.environment
  }
}

# Outputs
output "api_gateway_url" {
  description = "The URL of the API Gateway"
  value       = "${aws_apigatewayv2_api.chatbot_api.api_endpoint}${local.env_vars.environment}"
}

output "lambda_function_name" {
  description = "The name of the Lambda function"
  value       = aws_lambda_function.chatbot_lambda.function_name
}

output "lambda_function_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.chatbot_lambda.arn
}

output "api_gateway_id" {
  description = "The ID of the API Gateway"
  value       = aws_apigatewayv2_api.chatbot_api.id
}

output "environment" {
  description = "The deployment environment"
  value       = local.env_vars.environment
}

output "project_name" {
  description = "The project name"
  value       = local.env_vars.project_name
}
