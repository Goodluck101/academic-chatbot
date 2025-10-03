variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "academic-chatbot"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "bedrock_model_id" {
  description = "Bedrock model ID to use"
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "max_tokens" {
  description = "Maximum tokens for Bedrock response"
  type        = number
  default     = 1000
}

variable "temperature" {
  description = "Temperature for Bedrock model"
  type        = number
  default     = 0.5
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 128
}

variable "lambda_runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "python3.9"
}

variable "allowed_origins" {
  description = "Allowed origins for CORS"
  type        = string
  default     = "*"
}

# Terraform state configuration
variable "tf_state_bucket" {
  description = "S3 bucket for Terraform state"
  type        = string
  default     = "academic-chatbot-tf-state"
}

variable "tf_state_key" {
  description = "Terraform state key"
  type        = string
  default     = "terraform.tfstate"
}