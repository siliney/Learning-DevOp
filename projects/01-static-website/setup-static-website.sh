#!/bin/bash

# AWS S3 Static Website Setup Script
# Usage: ./setup-static-website.sh <bucket-name> <domain-name>

BUCKET_NAME=$1
DOMAIN_NAME=$2

if [ -z "$BUCKET_NAME" ] || [ -z "$DOMAIN_NAME" ]; then
    echo "Usage: $0 <bucket-name> <domain-name>"
    exit 1
fi

echo "Creating S3 bucket: $BUCKET_NAME"
aws s3 mb s3://$BUCKET_NAME

echo "Enabling static website hosting"
aws s3 website s3://$BUCKET_NAME --index-document index.html --error-document error.html

echo "Setting bucket policy for public read"
cat > bucket-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
        }
    ]
}
EOF

aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy file://bucket-policy.json

echo "Uploading sample website"
echo "<h1>Hello Cloud DevOps!</h1>" > index.html
aws s3 cp index.html s3://$BUCKET_NAME/

echo "Website URL: http://$BUCKET_NAME.s3-website-us-east-1.amazonaws.com"
echo "Setup complete!"
