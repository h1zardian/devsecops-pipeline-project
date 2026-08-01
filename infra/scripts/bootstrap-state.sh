#!/usr/bin/env bash
set -euo pipefail

# Script to bootstrap S3 Bucket and DynamoDB Table for Terraform Remote State
AWS_REGION="${AWS_REGION:-ap-south-1}"
BUCKET_NAME="${TF_STATE_BUCKET:-devsecops-tf-state-backend-072329308666}"
DYNAMODB_TABLE="${TF_LOCK_TABLE:-devsecops-tf-locks}"

echo "==> Bootstrapping Terraform Remote State Backend"
echo "Region: ${AWS_REGION}"
echo "S3 Bucket: ${BUCKET_NAME}"
echo "DynamoDB Table: ${DYNAMODB_TABLE}"

# Create S3 Bucket if it doesn't exist
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
  echo "S3 bucket ${BUCKET_NAME} already exists."
else
  echo "Creating S3 bucket ${BUCKET_NAME}..."
  if [ "${AWS_REGION}" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${AWS_REGION}"
  else
    aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${AWS_REGION}" \
      --create-bucket-configuration LocationConstraint="${AWS_REGION}"
  fi
  aws s3api put-bucket-versioning --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled
  aws s3api put-bucket-encryption --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
fi

# Create DynamoDB Table if it doesn't exist
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}" 2>/dev/null; then
  echo "DynamoDB table ${DYNAMODB_TABLE} already exists."
else
  echo "Creating DynamoDB table ${DYNAMODB_TABLE}..."
  aws dynamodb create-table \
    --table-name "${DYNAMODB_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${AWS_REGION}"
fi

echo "==> Backend bootstrap completed successfully!"
