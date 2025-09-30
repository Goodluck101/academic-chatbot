#!/bin/bash

# Load environment variables
set -a
source ../.env
set +a

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if .env file exists
if [ ! -f "../.env" ]; then
    print_error ".env file not found. Please create it from .env.example"
    exit 1
fi

# Validate required environment variables
required_vars=("AWS_REGION" "AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "PROJECT_NAME")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        print_error "Required environment variable $var is not set"
        exit 1
    fi
done

print_status "Starting deployment for project: $PROJECT_NAME"
print_status "Environment: ${ENVIRONMENT:-dev}"
print_status "AWS Region: $AWS_REGION"

# Generate terraform.tfvars from environment variables
print_status "Generating terraform.tfvars..."
cat > ../terraform/terraform.tfvars << EOF
# Generated from environment variables - $(date)
aws_region = "$AWS_REGION"
project_name = "$PROJECT_NAME"
environment = "${ENVIRONMENT:-dev}"
bedrock_model_id = "${BEDROCK_MODEL_ID:-anthropic.claude-3-haiku-20240307-v1:0}"
max_tokens = ${MAX_TOKENS:-1000}
temperature = ${TEMPERATURE:-0.5}
lambda_timeout = ${LAMBDA_TIMEOUT:-30}
lambda_memory_size = ${LAMBDA_MEMORY_SIZE:-128}
lambda_runtime = "${LAMBDA_RUNTIME:-python3.9}"
allowed_origins = "${FRONTEND_DOMAIN:-*}"
EOF

print_status "terraform.tfvars generated successfully"

# Create Lambda deployment package
print_status "Creating Lambda deployment package..."
cd ../backend

# Check if virtual environment exists, create if not
if [ ! -d "venv" ]; then
    print_status "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
print_status "Installing Python dependencies..."
pip install -r requirements.txt

# Create deployment package
print_status "Creating deployment package..."
zip -r lambda_function.zip lambda_function.py

# Check if zip was created successfully
if [ ! -f "lambda_function.zip" ]; then
    print_error "Failed to create Lambda deployment package"
    exit 1
fi

print_status "Lambda deployment package created successfully"

# Deploy with Terraform
print_status "Deploying infrastructure with Terraform..."
cd ../terraform

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    print_status "Initializing Terraform..."
    terraform init -backend-config="bucket=${TF_STATE_BUCKET:-academic-chatbot-tf-state}" -backend-config="key=${TF_STATE_KEY:-terraform.tfstate}" -backend-config="region=$AWS_REGION"
fi

# Plan deployment
print_status "Planning Terraform deployment..."
terraform plan -out deployment.tfplan

# Ask for confirmation
read -p "Do you want to apply this deployment? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Applying Terraform deployment..."
    terraform apply deployment.tfplan
    
    # Get API Gateway URL
    API_URL=$(terraform output -raw api_gateway_chat_endpoint)
    
    if [ -z "$API_URL" ]; then
        print_error "Failed to get API Gateway URL from Terraform outputs"
        exit 1
    fi
    
    print_status "Deployment completed successfully!"
    print_status "API Gateway URL: $API_URL"
    
    # Update frontend configuration
    print_status "Updating frontend configuration..."
    cd ../frontend
    
    # Create config.json for frontend
    cat > config.json << EOF
{
    "API_GATEWAY_URL": "$API_URL",
    "PROJECT_NAME": "$PROJECT_NAME",
    "ENVIRONMENT": "${ENVIRONMENT:-dev}",
    "AWS_REGION": "$AWS_REGION"
}
EOF

    print_status "Frontend configuration updated:"
    echo "=== config.json ==="
    cat config.json
    echo "==================="
    
    # Create a deployment summary
    print_status "Creating deployment summary..."
    cd ..
    cat > deployment-summary.txt << EOF
Academic Chatbot Deployment Summary
===================================

Project: $PROJECT_NAME
Environment: ${ENVIRONMENT:-dev}
AWS Region: $AWS_REGION
Deployment Time: $(date)

API Endpoints:
- Chat API: $API_URL

Frontend:
- Open frontend/index.html in a web browser
- Configuration: frontend/config.json

Testing Commands:
# Test the API
curl -X POST $API_URL \\
  -H "Content-Type: application/json" \\
  -d '{"message": "What is photosynthesis?"}'

# View Lambda logs
aws logs tail /aws/lambda/${PROJECT_NAME}-${ENVIRONMENT:-dev}-function --follow

Terraform Outputs:
$(cd terraform && terraform output)

EOF

    print_status "Deployment summary saved to: deployment-summary.txt"
    
else
    print_warning "Deployment cancelled"
    exit 0
fi

print_status "Deployment process completed!"