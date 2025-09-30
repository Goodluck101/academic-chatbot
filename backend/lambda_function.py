import json
import boto3
import os
import logging
from typing import Dict, Any, Optional

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

class Config:
    """Configuration class to manage environment variables"""
    
    @staticmethod
    def get_aws_region() -> str:
        return os.environ.get('AWS_REGION', 'us-east-1')
    
    @staticmethod
    def get_bedrock_model_id() -> str:
        return os.environ.get('BEDROCK_MODEL_ID', 'anthropic.claude-3-haiku-20240307-v1:0')
    
    @staticmethod
    def get_max_tokens() -> int:
        return int(os.environ.get('MAX_TOKENS', '1000'))
    
    @staticmethod
    def get_temperature() -> float:
        return float(os.environ.get('TEMPERATURE', '0.5'))
    
    @staticmethod
    def get_allowed_origins() -> str:
        return os.environ.get('ALLOWED_ORIGINS', '*')
    
    @staticmethod
    def get_environment() -> str:
        return os.environ.get('ENVIRONMENT', 'dev')

class BedrockClient:
    """Client for interacting with Amazon Bedrock"""
    
    def __init__(self):
        self.region = Config.get_aws_region()
        self.client = boto3.client('bedrock-runtime', region_name=self.region)
        self.model_id = Config.get_bedrock_model_id()
    
    def generate_response(self, prompt: str) -> str:
        """Generate response using Bedrock"""
        try:
            body = {
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": Config.get_max_tokens(),
                "temperature": Config.get_temperature(),
                "messages": [
                    {
                        "role": "user",
                        "content": prompt
                    }
                ]
            }
            
            response = self.client.invoke_model(
                modelId=self.model_id,
                body=json.dumps(body)
            )
            
            response_body = json.loads(response['body'].read())
            content = response_body['content']
            
            if content and len(content) > 0:
                return content[0]['text']
            else:
                return "I apologize, but I couldn't generate a response. Please try again with a different question."
                
        except Exception as e:
            logger.error(f"Error generating response with Bedrock: {str(e)}")
            raise e

class AcademicChatbot:
    """Main chatbot class"""
    
    def __init__(self):
        self.bedrock_client = BedrockClient()
    
    def create_prompt(self, user_message: str) -> str:
        """Create academic-focused prompt"""
        return f"""Human: You are an academic assistant designed to help students and researchers with educational topics. 
        Please provide a helpful, accurate, and educational response to the following question. 
        If the question is not academic in nature, politely guide the user back to academic topics.
        
        Question: {user_message}
        
        Please provide a comprehensive yet concise answer. If appropriate, you can:
        1. Explain key concepts
        2. Provide examples
        3. Suggest related topics for further study
        4. Mention important principles or theories
        
        Assistant:"""
    
    def process_message(self, user_message: str) -> str:
        """Process user message and return response"""
        prompt = self.create_prompt(user_message)
        return self.bedrock_client.generate_response(prompt)

def create_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """Create standardized HTTP response"""
    allowed_origins = Config.get_allowed_origins()
    
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': allowed_origins,
            'Access-Control-Allow-Methods': 'POST, OPTIONS, GET',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Credentials': 'true'
        },
        'body': json.dumps(body)
    }

def validate_request(body: Dict[str, Any]) -> Optional[str]:
    """Validate the incoming request"""
    if not body:
        return "Request body is required"
    
    user_message = body.get('message', '').strip()
    if not user_message:
        return "Message is required"
    
    if len(user_message) > 1000:
        return "Message is too long. Maximum 1000 characters allowed."
    
    return None

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda function handler for the academic chatbot
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Handle preflight OPTIONS request
        if event.get('httpMethod') == 'OPTIONS':
            return create_response(200, {})
        
        # Parse the request body
        if 'body' in event and event['body']:
            if isinstance(event['body'], str):
                body = json.loads(event['body'])
            else:
                body = event['body']
        else:
            body = {}
        
        # Validate request
        validation_error = validate_request(body)
        if validation_error:
            return create_response(400, {'error': validation_error})
        
        user_message = body.get('message', '').strip()
        
        # Initialize chatbot and process message
        chatbot = AcademicChatbot()
        bot_response = chatbot.process_message(user_message)
        
        return create_response(200, {
            'response': bot_response,
            'environment': Config.get_environment(),
            'model_used': Config.get_bedrock_model_id()
        })
        
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {str(e)}")
        return create_response(400, {'error': 'Invalid JSON in request body'})
        
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}")
        return create_response(500, {
            'error': 'Internal server error',
            'environment': Config.get_environment()
        })

# For local testing
if __name__ == "__main__":
    # Set environment variables for local testing
    os.environ['AWS_REGION'] = 'us-east-1'
    os.environ['BEDROCK_MODEL_ID'] = 'anthropic.claude-3-haiku-20240307-v1:0'
    os.environ['MAX_TOKENS'] = '1000'
    os.environ['TEMPERATURE'] = '0.5'
    os.environ['ALLOWED_ORIGINS'] = '*'
    os.environ['ENVIRONMENT'] = 'local'
    
    # Test event
    test_event = {
        'body': json.dumps({
            'message': 'What is photosynthesis?'
        })
    }
    
    result = lambda_handler(test_event, None)
    print("Test result:", json.dumps(result, indent=2))
