import boto3

# Connect to LocalStack
s3 = boto3.client('s3', endpoint_url='http://192.168.67.2:31566')

# Create a dummy file
with open("receipt.txt", "w") as f:
    f.write("This is a $500 receipt.")

print("Uploading file...")
s3.upload_file("receipt.txt", "project-bucket", "receipt.txt")
print("Upload Complete! Check the Lambda logs.")
