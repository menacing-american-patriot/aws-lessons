import json
import urllib.parse

def lambda_handler(event, context):
    # Get the object from the event
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
    
    print(f"AUTOMATION ALERT: File '{key}' was uploaded to bucket '{bucket}'.")
    
    return "Process Complete"
