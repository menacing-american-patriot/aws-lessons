import json
import os
import uuid
import boto3

# Get the table name from the environment variable
TABLE_NAME = os.environ.get('TABLE_NAME', 'Notes')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(TABLE_NAME)

def lambda_handler(event, context):
    """
    Handles creating and retrieving notes from DynamoDB.
    """
    print(f"Received event: {json.dumps(event)}")
    
    http_method = event.get('httpMethod')
    path = event.get('path')

    try:
        if http_method == 'POST' and path == '/notes':
            return create_note(event)
        elif http_method == 'GET' and path.startswith('/notes/'):
            return get_note(event)
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Invalid method or path'})
            }
    except Exception as e:
        print(f"Error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def create_note(event):
    """
    Creates a new note in the DynamoDB table.
    """
    body = json.loads(event.get('body', '{}'))
    content = body.get('content')

    if not content:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Missing "content" in request body'})
        }

    note_id = str(uuid.uuid4())
    
    item = {
        'noteId': note_id,
        'content': content
    }

    table.put_item(Item=item)

    return {
        'statusCode': 201,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({'noteId': note_id})
    }

def get_note(event):
    """
    Retrieves a note from the DynamoDB table.
    """
    try:
        note_id = event['pathParameters']['noteId']
    except (KeyError, TypeError):
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Missing noteId in path'})
        }

    response = table.get_item(Key={'noteId': note_id})
    item = response.get('Item')

    if not item:
        return {
            'statusCode': 404,
            'body': json.dumps({'error': 'Note not found'})
        }

    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps(item)
    }
