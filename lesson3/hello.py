import json

def lambda_handler(event, context):
    print("Log: The function was triggered!")
    return {
        'statusCode': 200,
        'body': json.dumps('Hello! This is a Serverless response.')
    }
