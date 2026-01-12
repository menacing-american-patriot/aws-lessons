# main.2.tf

# ---------------------------------------------------------
# 1. Provider Configuration (The "Fake Cloud" Setup)
# ---------------------------------------------------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  
  # Skip real AWS validations
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  # CRITICAL FOR LOCALHOST: 
  # Forces URL to be http://localhost:4566/bucket-name
  # instead of http://bucket-name.localhost:4566 (which requires DNS hacks)
  s3_use_path_style           = true

  endpoints {
    s3 = "http://192.168.67.2:31566"
  }
}

# ---------------------------------------------------------
# 2. The Infrastructure Resources
# ---------------------------------------------------------

# Create the Bucket
resource "aws_s3_bucket" "website_bucket" {
  bucket = "my-local-site"
}

# Configure the Bucket to act as a Website
resource "aws_s3_bucket_website_configuration" "site_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Upload the HTML file automatically
resource "aws_s3_object" "upload_html" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "index.html"        # Name in the cloud
  source       = "index.html"        # Name on your disk (must exist!)
  
  # TEACHING POINT: Without this, S3 defaults to "binary/octet-stream"
  # and the browser would download the file instead of showing it.
  content_type = "text/html" 
}

# ---------------------------------------------------------
# 3. Outputs (What to type in the browser)
# ---------------------------------------------------------
output "website_url" {
  description = "Click this URL to view your local website"
  value       = "http://192.168.67.2:31566/my-local-site/index.html"
}
