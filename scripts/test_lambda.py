#!/usr/bin/env python3
"""
Test script for the Lambda function locally
"""

import os
import sys
import json

# Add the backend directory to the path
sys.path.append(os.path.join(os.path.dirname(__file__), '../backend'))

from lambda_function import lambda_handler

def test_lambda_function():
    """Test the Lambda function with sample events"""
    
    # Set environment variables for testing
    os.environ['AWS_REGION'] = 'us-east-1'
    os.environ['BEDROCK_MODEL_ID'] = 'anthropic.claude-3-haiku-20240307-v1:0'
    os.environ['MAX_TOKENS'] = '1000'
    os.environ['TEMPERATURE'] = '0.5'
    os.environ['ALLOWED_ORIGINS'] = '*'
    os.environ['ENVIRONMENT'] = 'test'
    os.environ['PROJECT_NAME'] = 'academic-chatbot-test'
    
    # Test events
    test_events = [
        {
            'body': json.dumps({
                'message': 'What is photosynthesis?'
            })
        },
        {
            'body': json.dumps({
                'message': 'Explain quantum physics basics'
            })
        },
        {
            'body': json.dumps({
                'message': ''  # Empty message test
            })
        },
        {
            'body': 'invalid json'  # Invalid JSON test
        }
    ]
    
    print("Testing Lambda Function...")
    print("=" * 50)
    
    for i, event in enumerate(test_events, 1):
        print(f"\nTest {i}:")
        print(f"Input: {event}")
        
        try:
            result = lambda_handler(event, None)
            print(f"Status Code: {result['statusCode']}")
            print(f"Headers: {result['headers']}")
            
            if 'body' in result:
                body = json.loads(result['body'])
                print(f"Response Body: {json.dumps(body, indent=2)}")
                
        except Exception as e:
            print(f"Error: {str(e)}")
        
        print("-" * 30)

if __name__ == "__main__":
    test_lambda_function()
