# AWS Lessons

* We are self hosting an aws emulator on my server to learn the basics of AWS and terraform

**Important commands:**

```bash
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"
```

or

```bash
source .env
```

**We must forward the ports in a background terminal**

```bash
kubectl port-forward svc/local-aws-localstack 4566:4566
```

Then we test to make sure the shell read the environment variables. This next command should have no output.

```bash
aws s3 ls
```

## AWS CLI Lesson 1

* Move to the lesson 1 directory

```bash
cd lesson1
```

make sure our endpoint alias is set

```bash
alias aws="aws --endpoint-url=http://localhost:4566"
```

Else we will have to run this every time instead of just aws:

```bash
aws --endpoint-url=http://localhost:4566
```

**Now we can create resources**

```bash
# Create an S3 Bucket
aws --endpoint-url=http://localhost:4566 s3 mb s3://my-test-bucket

# Create a DynamoDB Table
aws --endpoint-url=http://localhost:4566 dynamodb create-table \
    --table-name UserUploads \
    --attribute-definitions AttributeName=filename,AttributeType=S \
    --key-schema AttributeName=filename,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
```

**We will even "deploy" an app using a python script:**

```python
import boto3

# This connects to your self-hosted LocalStack instead of real AWS
s3 = boto3.client('s3', endpoint_url='http://localhost:4566')

s3.upload_file('test.txt', 'my-test-bucket', 'test.txt')
print("Uploaded to local server!")
```

## Terraform lesson

* Step A: Initialize (*terraform init*) Run this to download the AWS plugin.

```bash
terraform init
```

**Teaching Point:** "This downloads the tools Terraform needs to talk to AWS. It's like installing a driver."

* Step B: Plan (*terraform plan*) Run this to see what would happen.

```bash
terraform plan
```

**Teaching Point:** "Terraform compares what we wrote in code to what currently exists in the 'cloud'. It sees that the bucket doesn't exist yet, so it plans to create it."

* Step C: Apply (*terraform apply*) Run this to actually do it. Type yes when asked.

```bash
terraform apply
```

* **Voila**

Now, verify the resources exist using your manual CLI alias.

```bash
# Check for the bucket
aws s3 ls
# Output should show: terraform-is-cool

# Check for the database
aws dynamodb list-tables
# Output should show: StudentGrades
```

* 4. The Grand Finale (Destruction)

We are done with the project. How do we clean up so we don't get 'billed'?

**Instead of clicking delete on every item, run:**

```bash
terraform destroy
```

**Teaching Point:** This cleans up everything defined in the code automatically. It ensures no stray resources are left behind costing money.

## Lesson 2: Hosting a Static Website

**Goal:** Use S3 to host a raw HTML file that can be viewed in a browser.

**Prep the Workspace**

We use a separate directory so Terraform doesn't get confused with Lesson 1's state.

```bash
cd ~/aws-lessons/lesson2
```

**Deploy our site**

```bash
terraform init
terraform apply
```

**Validation** Since we are on a headless VPS, use curl to prove the site is active:

```bash
curl http://localhost:4566/my-local-site/index.html
```

We should now see the HTML code printed in the terminal

## Lesson 3: Serverless Compute (Lambda)

**Goal:** Run Python code in the "cloud" without provisioning a server.

**Prep the Workspace**

```bash
cd ~/aws-lessons/lesson3
```

**Deploy**

```bash
terraform init
terraform apply
```

**Trigger the function**

```bash
# Invoke the function and save the result to response.json
aws lambda invoke --function-name my-first-function response.json

# Read the output
cat response.json
```

**Expected Output:** "Hello! This is a Serverless response."

## **Lesson 4:** Event-Driven Architecture

**Goal:** Upload a file to S3, which instantly triggers a Lambda function to print the filename.

```bash
cd ~/aws-lessons/lesson4
```

**. Run the Test** Ensure your virtual environment is active (source ../venv/bin/activate) and run:

```bash
python3 upload_trigger.py
```

**7. Validation** Check the logs of the Lambda function to see if it woke up and processed the file:

```bash
aws lambda logs tail file-processor
```

You should see: *AUTOMATION ALERT: File 'receipt.txt' was uploaded...*
