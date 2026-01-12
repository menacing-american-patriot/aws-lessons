import json

def lambda_handler(event, context):
    """
    This function handles requests from the API Gateway.
    It returns a simple JSON response.
    """
    print(f"Received event: {json.dumps(event)}")

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps({
            "message": "Hello from your API-powered Lambda!",
            "input": event
        })
    }