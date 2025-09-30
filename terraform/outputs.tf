output "api_gateway_url" {
  description = "The base URL of the API Gateway"
  value       = "${aws_apigatewayv2_api.chatbot_api.api_endpoint}${var.environment}"
}

output "api_gateway_chat_endpoint" {
  description = "The full chat endpoint URL"
  value       = "${aws_apigatewayv2_api.chatbot_api.api_endpoint}${var.environment}/chat"
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
  value       = var.environment
}

output "project_name" {
  description = "The project name"
  value       = var.project_name
}

output "aws_region" {
  description = "The AWS region where resources are deployed"
  value       = var.aws_region
}

output "bedrock_model_id" {
  description = "The Bedrock model ID being used"
  value       = var.bedrock_model_id
}

output "frontend_config" {
  description = "Configuration for the frontend application"
  value = {
    api_gateway_url = "${aws_apigatewayv2_api.chatbot_api.api_endpoint}${var.environment}/chat"
    project_name    = var.project_name
    environment     = var.environment
    aws_region      = var.aws_region
  }
}

output "deployment_instructions" {
  description = "Instructions for completing the deployment"
  value = <<EOT

Academic Chatbot Deployment Complete!

Next Steps:
1. Update your frontend configuration:
   - Copy the API Gateway URL above to frontend/config.json
   - Or update the apiUrl in frontend/script.js

2. Test the API endpoint:
   curl -X POST ${aws_apigatewayv2_api.chatbot_api.api_endpoint}${var.environment}/chat \
     -H "Content-Type: application/json" \
     -d '{"message": "What is photosynthesis?"}'

3. Open frontend/index.html in a web browser to test the chatbot

4. Monitor CloudWatch logs for the Lambda function:
   aws logs tail /aws/lambda/${aws_lambda_function.chatbot_lambda.function_name} --follow

EOT
}
