#!/bin/bash

# ================================
# Setup
# ================================

# Get absolute path of the project root (parent of scripts/)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Path to .env file in project root
ENV_FILE="$PROJECT_ROOT/.env"

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

# ================================
# Load environment variables
# ================================
set -a
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
    print_status "Loaded environment variables from $ENV_FILE"
else
    print_error ".env file not found at $ENV_FILE. Please create it from .env.example"
    exit 1
fi
set +a

# Validate required environment variables
required_vars=("AWS_REGION" "AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "PROJECT_NAME")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        print_error "Required environment variable $var is not set"
        exit 1
    fi
done

# ================================
# Deployment process
# ================================

print_status "Starting deployment for project: $PROJECT_NAME"
print_status "Environment: ${ENVIRONMENT:-dev}"
print_status "AWS Region: $AWS_REGION"

# Generate terraform.tfvars from environment variables
print_status "Generating terraform.tfvars..."
cat > "$PROJECT_ROOT/terraform/terraform.tfvars" << EOF
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
cd "$PROJECT_ROOT/backend"

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
cd "$PROJECT_ROOT/terraform"

# ================================
# Enhanced Terraform Initialization
# ================================

# Check if S3 bucket exists for Terraform state
print_status "Checking if S3 bucket exists for Terraform state..."
BUCKET_NAME="${TF_STATE_BUCKET:-academic-chatbot-tf-state}"
if ! aws s3 ls "s3://$BUCKET_NAME" 2>&1 | grep -q 'NoSuchBucket'; then
    print_status "S3 bucket $BUCKET_NAME exists"
else
    print_warning "S3 bucket $BUCKET_NAME does not exist. Creating it now..."
    
    # Create the S3 bucket
    if aws s3 mb "s3://$BUCKET_NAME" --region "$AWS_REGION"; then
        print_status "S3 bucket $BUCKET_NAME created successfully"
        
        # Wait a moment for bucket creation to propagate
        print_status "Waiting for S3 bucket creation to propagate..."
        sleep 10
    else
        print_error "Failed to create S3 bucket $BUCKET_NAME"
        print_error "Please create it manually with: aws s3 mb s3://$BUCKET_NAME --region $AWS_REGION"
        exit 1
    fi
fi

# Initialize Terraform (always run to ensure backend is configured)
print_status "Initializing Terraform backend and providers..."
terraform init -reconfigure \
    -backend-config="bucket=$BUCKET_NAME" \
    -backend-config="key=${TF_STATE_KEY:-terraform.tfstate}" \
    -backend-config="region=$AWS_REGION"

# Check if initialization was successful
if [ $? -ne 0 ]; then
    print_error "Terraform initialization failed"
    print_error "Please check your AWS credentials and S3 bucket configuration"
    exit 1
fi

print_status "Terraform initialized successfully"

# Validate Terraform configuration
print_status "Validating Terraform configuration..."
if ! terraform validate; then
    print_error "Terraform configuration validation failed"
    print_error "Please check your Terraform files for errors"
    exit 1
fi

print_status "Terraform configuration validated successfully"

# ================================
# Deployment Planning and Execution
# ================================

# Plan deployment
print_status "Planning Terraform deployment..."
terraform plan -out deployment.tfplan

# Check if plan was created successfully
if [ ! -f "deployment.tfplan" ]; then
    print_error "Failed to create Terraform deployment plan"
    exit 1
fi

# Ask for confirmation
echo
print_warning "This will deploy the following AWS resources:"
print_warning "- Lambda Function: ${PROJECT_NAME}-${ENVIRONMENT:-dev}-function"
print_warning "- API Gateway: ${PROJECT_NAME}-${ENVIRONMENT:-dev}-api"
print_warning "- IAM Role and Policies"
print_warning "- CloudWatch Log Group"
echo

read -p "Do you want to apply this deployment? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Applying Terraform deployment..."
    
    # Apply the deployment
    if terraform apply deployment.tfplan; then
        print_status "Terraform deployment applied successfully"
    else
        print_error "Terraform deployment failed"
        exit 1
    fi
    
    # Get API Gateway URL
    print_status "Retrieving deployment outputs..."
    API_URL=$(terraform output -raw api_gateway_chat_endpoint 2>/dev/null)
    
    if [ -z "$API_URL" ]; then
        print_warning "Could not retrieve API Gateway URL from outputs, trying alternative method..."
        API_URL=$(terraform output -raw api_gateway_url 2>/dev/null)
        if [ -n "$API_URL" ]; then
            API_URL="${API_URL}/chat"
        fi
    fi
    
    if [ -z "$API_URL" ]; then
        print_error "Failed to get API Gateway URL from Terraform outputs"
        print_error "Please check the deployment and run: terraform output"
        exit 1
    fi
    
    print_status "Deployment completed successfully!"
    print_status "API Gateway URL: $API_URL"
    
    # Update frontend configuration
    print_status "Updating frontend configuration..."
    cd "$PROJECT_ROOT/frontend"
    
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
    cd "$PROJECT_ROOT"
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
curl -X POST "$API_URL" \\
  -H "Content-Type: application/json" \\
  -d '{"message": "What is photosynthesis?"}'

# View Lambda logs
aws logs tail /aws/lambda/${PROJECT_NAME}-${ENVIRONMENT:-dev}-function --follow

# Check deployment status
cd terraform && terraform output

EOF

    print_status "Deployment summary saved to: deployment-summary.txt"
    
    # Display quick test instructions
    echo
    print_status "Quick test:"
    print_status "1. Open frontend/index.html in your browser"
    print_status "2. Or test the API directly:"
    print_status "   curl -X POST '$API_URL' \\"
    print_status "     -H 'Content-Type: application/json' \\"
    print_status "     -d '{\"message\": \"Hello\"}'"
    echo
    
else
    print_warning "Deployment cancelled"
    print_status "You can run the deployment later with: ./scripts/deploy.sh"
    exit 0
fi

print_status "Deployment process completed!"



# ################################

# # ================================
# # Setup
# # ================================

# # Get absolute path of the project root (parent of scripts/)
# SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# # Path to .env file in project root
# ENV_FILE="$PROJECT_ROOT/.env"

# # Colors for output
# RED='\033[0;31m'
# GREEN='\033[0;32m'
# YELLOW='\033[1;33m'
# NC='\033[0m' # No Color

# # Function to print colored output
# print_status() {
#     echo -e "${GREEN}[INFO]${NC} $1"
# }

# print_warning() {
#     echo -e "${YELLOW}[WARNING]${NC} $1"
# }

# print_error() {
#     echo -e "${RED}[ERROR]${NC} $1"
# }

# # ================================
# # Load environment variables
# # ================================
# set -a
# if [ -f "$ENV_FILE" ]; then
#     source "$ENV_FILE"
#     print_status "Loaded environment variables from $ENV_FILE"
# else
#     print_error ".env file not found at $ENV_FILE. Please create it from .env.example"
#     exit 1
# fi
# set +a

# # Validate required environment variables
# required_vars=("AWS_REGION" "AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "PROJECT_NAME")
# for var in "${required_vars[@]}"; do
#     if [ -z "${!var}" ]; then
#         print_error "Required environment variable $var is not set"
#         exit 1
#     fi
# done

# # ================================
# # Deployment process
# # ================================

# print_status "Starting deployment for project: $PROJECT_NAME"
# print_status "Environment: ${ENVIRONMENT:-dev}"
# print_status "AWS Region: $AWS_REGION"

# # Generate terraform.tfvars from environment variables
# print_status "Generating terraform.tfvars..."
# cat > "$PROJECT_ROOT/terraform/terraform.tfvars" << EOF
# # Generated from environment variables - $(date)
# aws_region = "$AWS_REGION"
# project_name = "$PROJECT_NAME"
# environment = "${ENVIRONMENT:-dev}"
# bedrock_model_id = "${BEDROCK_MODEL_ID:-anthropic.claude-3-haiku-20240307-v1:0}"
# max_tokens = ${MAX_TOKENS:-1000}
# temperature = ${TEMPERATURE:-0.5}
# lambda_timeout = ${LAMBDA_TIMEOUT:-30}
# lambda_memory_size = ${LAMBDA_MEMORY_SIZE:-128}
# lambda_runtime = "${LAMBDA_RUNTIME:-python3.9}"
# allowed_origins = "${FRONTEND_DOMAIN:-*}"
# EOF

# print_status "terraform.tfvars generated successfully"

# # Create Lambda deployment package
# print_status "Creating Lambda deployment package..."
# cd "$PROJECT_ROOT/backend"

# # Check if virtual environment exists, create if not
# if [ ! -d "venv" ]; then
#     print_status "Creating virtual environment..."
#     python3 -m venv venv
# fi

# # Activate virtual environment
# source venv/bin/activate

# # Install dependencies
# print_status "Installing Python dependencies..."
# pip install -r requirements.txt

# # Create deployment package
# print_status "Creating deployment package..."
# zip -r lambda_function.zip lambda_function.py

# # Check if zip was created successfully
# if [ ! -f "lambda_function.zip" ]; then
#     print_error "Failed to create Lambda deployment package"
#     exit 1
# fi

# print_status "Lambda deployment package created successfully"

# # Deploy with Terraform
# print_status "Deploying infrastructure with Terraform..."
# cd "$PROJECT_ROOT/terraform"

# # Initialize Terraform if needed
# if [ ! -d ".terraform" ]; then
#     print_status "Initializing Terraform..."
#     terraform init -backend-config="bucket=${TF_STATE_BUCKET:-academic-chatbot-tf-state}" \
#                    -backend-config="key=${TF_STATE_KEY:-terraform.tfstate}" \
#                    -backend-config="region=$AWS_REGION"
# fi

# # Plan deployment
# print_status "Planning Terraform deployment..."
# terraform plan -out deployment.tfplan

# # Ask for confirmation
# read -p "Do you want to apply this deployment? (y/n): " -n 1 -r
# echo
# if [[ $REPLY =~ ^[Yy]$ ]]; then
#     print_status "Applying Terraform deployment..."
#     terraform apply deployment.tfplan
    
#     # Get API Gateway URL
#     API_URL=$(terraform output -raw api_gateway_chat_endpoint)
    
#     if [ -z "$API_URL" ]; then
#         print_error "Failed to get API Gateway URL from Terraform outputs"
#         exit 1
#     fi
    
#     print_status "Deployment completed successfully!"
#     print_status "API Gateway URL: $API_URL"
    
#     # Update frontend configuration
#     print_status "Updating frontend configuration..."
#     cd "$PROJECT_ROOT/frontend"
    
#     # Create config.json for frontend
#     cat > config.json << EOF
# {
#     "API_GATEWAY_URL": "$API_URL",
#     "PROJECT_NAME": "$PROJECT_NAME",
#     "ENVIRONMENT": "${ENVIRONMENT:-dev}",
#     "AWS_REGION": "$AWS_REGION"
# }
# EOF

#     print_status "Frontend configuration updated:"
#     echo "=== config.json ==="
#     cat config.json
#     echo "==================="

#     # Create a deployment summary
#     print_status "Creating deployment summary..."
#     cd "$PROJECT_ROOT"
#     cat > deployment-summary.txt << EOF
# Academic Chatbot Deployment Summary
# ===================================

# Project: $PROJECT_NAME
# Environment: ${ENVIRONMENT:-dev}
# AWS Region: $AWS_REGION
# Deployment Time: $(date)

# API Endpoints:
# - Chat API: $API_URL

# Frontend:
# - Open frontend/index.html in a web browser
# - Configuration: frontend/config.json

# Testing Commands:
# # Test the API
# curl -X POST $API_URL \\
#   -H "Content-Type: application/json" \\
#   -d '{"message": "What is photosynthesis?"}'

# # View Lambda logs
# aws logs tail /aws/lambda/${PROJECT_NAME}-${ENVIRONMENT:-dev}-function --follow

# Terraform Outputs:
# $(cd "$PROJECT_ROOT/terraform" && terraform output)

# EOF

#     print_status "Deployment summary saved to: deployment-summary.txt"
    
# else
#     print_warning "Deployment cancelled"
#     exit 0
# fi

# print_status "Deployment process completed!"



##############################


# # Get absolute path of the project root (parent of scripts/)
# SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# # Path to .env file in project root
# ENV_FILE="$PROJECT_ROOT/.env"

# set -a
# if [ -f "$ENV_FILE" ]; then
#   source "$ENV_FILE"
#   echo "[INFO] Loaded environment variables from $ENV_FILE"
# else
#   echo "[ERROR] .env file not found at $ENV_FILE. Please create it from .env.example"
#   exit 1
# fi
# set +a

# # --- rest of your deploy commands follow here ---

# # Colors for output
# RED='\033[0;31m'
# GREEN='\033[0;32m'
# YELLOW='\033[1;33m'
# NC='\033[0m' # No Color

# # Function to print colored output
# print_status() {
#     echo -e "${GREEN}[INFO]${NC} $1"
# }

# print_warning() {
#     echo -e "${YELLOW}[WARNING]${NC} $1"
# }

# print_error() {
#     echo -e "${RED}[ERROR]${NC} $1"
# }

# # Check if .env file exists
# if [ ! -f "../.env" ]; then
#     print_error ".env file not found. Please create it from .env.example"
#     exit 1
# fi

# # Validate required environment variables
# required_vars=("AWS_REGION" "AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "PROJECT_NAME")
# for var in "${required_vars[@]}"; do
#     if [ -z "${!var}" ]; then
#         print_error "Required environment variable $var is not set"
#         exit 1
#     fi
# done

# print_status "Starting deployment for project: $PROJECT_NAME"
# print_status "Environment: ${ENVIRONMENT:-dev}"
# print_status "AWS Region: $AWS_REGION"

# # Generate terraform.tfvars from environment variables
# print_status "Generating terraform.tfvars..."
# cat > ../terraform/terraform.tfvars << EOF
# # Generated from environment variables - $(date)
# aws_region = "$AWS_REGION"
# project_name = "$PROJECT_NAME"
# environment = "${ENVIRONMENT:-dev}"
# bedrock_model_id = "${BEDROCK_MODEL_ID:-anthropic.claude-3-haiku-20240307-v1:0}"
# max_tokens = ${MAX_TOKENS:-1000}
# temperature = ${TEMPERATURE:-0.5}
# lambda_timeout = ${LAMBDA_TIMEOUT:-30}
# lambda_memory_size = ${LAMBDA_MEMORY_SIZE:-128}
# lambda_runtime = "${LAMBDA_RUNTIME:-python3.9}"
# allowed_origins = "${FRONTEND_DOMAIN:-*}"
# EOF

# print_status "terraform.tfvars generated successfully"

# # Create Lambda deployment package
# print_status "Creating Lambda deployment package..."
# cd ../backend

# # Check if virtual environment exists, create if not
# if [ ! -d "venv" ]; then
#     print_status "Creating virtual environment..."
#     python3 -m venv venv
# fi

# # Activate virtual environment
# source venv/bin/activate

# # Install dependencies
# print_status "Installing Python dependencies..."
# pip install -r requirements.txt

# # Create deployment package
# print_status "Creating deployment package..."
# zip -r lambda_function.zip lambda_function.py

# # Check if zip was created successfully
# if [ ! -f "lambda_function.zip" ]; then
#     print_error "Failed to create Lambda deployment package"
#     exit 1
# fi

# print_status "Lambda deployment package created successfully"

# # Deploy with Terraform
# print_status "Deploying infrastructure with Terraform..."
# cd ../terraform

# # Initialize Terraform if needed
# if [ ! -d ".terraform" ]; then
#     print_status "Initializing Terraform..."
#     terraform init -backend-config="bucket=${TF_STATE_BUCKET:-academic-chatbot-tf-state}" -backend-config="key=${TF_STATE_KEY:-terraform.tfstate}" -backend-config="region=$AWS_REGION"
# fi

# # Plan deployment
# print_status "Planning Terraform deployment..."
# terraform plan -out deployment.tfplan

# # Ask for confirmation
# read -p "Do you want to apply this deployment? (y/n): " -n 1 -r
# echo
# if [[ $REPLY =~ ^[Yy]$ ]]; then
#     print_status "Applying Terraform deployment..."
#     terraform apply deployment.tfplan
    
#     # Get API Gateway URL
#     API_URL=$(terraform output -raw api_gateway_chat_endpoint)
    
#     if [ -z "$API_URL" ]; then
#         print_error "Failed to get API Gateway URL from Terraform outputs"
#         exit 1
#     fi
    
#     print_status "Deployment completed successfully!"
#     print_status "API Gateway URL: $API_URL"
    
#     # Update frontend configuration
#     print_status "Updating frontend configuration..."
#     cd ../frontend
    
#     # Create config.json for frontend
#     cat > config.json << EOF
# {
#     "API_GATEWAY_URL": "$API_URL",
#     "PROJECT_NAME": "$PROJECT_NAME",
#     "ENVIRONMENT": "${ENVIRONMENT:-dev}",
#     "AWS_REGION": "$AWS_REGION"
# }
# EOF

#     print_status "Frontend configuration updated:"
#     echo "=== config.json ==="
#     cat config.json
#     echo "==================="
    
#     # Create a deployment summary
#     print_status "Creating deployment summary..."
#     cd ..
#     cat > deployment-summary.txt << EOF
# Academic Chatbot Deployment Summary
# ===================================

# Project: $PROJECT_NAME
# Environment: ${ENVIRONMENT:-dev}
# AWS Region: $AWS_REGION
# Deployment Time: $(date)

# API Endpoints:
# - Chat API: $API_URL

# Frontend:
# - Open frontend/index.html in a web browser
# - Configuration: frontend/config.json

# Testing Commands:
# # Test the API
# curl -X POST $API_URL \\
#   -H "Content-Type: application/json" \\
#   -d '{"message": "What is photosynthesis?"}'

# # View Lambda logs
# aws logs tail /aws/lambda/${PROJECT_NAME}-${ENVIRONMENT:-dev}-function --follow

# Terraform Outputs:
# $(cd terraform && terraform output)

# EOF

#     print_status "Deployment summary saved to: deployment-summary.txt"
    
# else
#     print_warning "Deployment cancelled"
#     exit 0
# fi

# print_status "Deployment process completed!"