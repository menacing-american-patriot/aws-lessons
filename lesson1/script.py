import boto3

# This connects to your self-hosted LocalStack instead of real AWS
s3 = boto3.client('s3', endpoint_url='http://localhost:4566')

s3.upload_file('test.txt', 'my-test-bucket', 'test.txt')
print("Uploaded to local server!")

