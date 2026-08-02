#!/usr/bin/env bash
set -euo pipefail

# Script to bootstrap S3 Bucket for Terraform Remote State.
# Note: DynamoDB locking has been replaced by S3-native locking (use_lockfile = true)
# which requires no additional infrastructure.
AWS_REGION="${AWS_REGION:-ap-south-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="${TF_STATE_BUCKET:-devsecops-tf-state-backend-${ACCOUNT_ID}}"

echo "==> Bootstrapping Terraform Remote State Backend"
echo "Region: ${AWS_REGION}"
echo "S3 Bucket: ${BUCKET_NAME}"

# Create S3 Bucket if it doesn't exist
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
  echo "S3 bucket ${BUCKET_NAME} already exists."
  BUCKET_REGION=$(aws s3api get-bucket-location --bucket "${BUCKET_NAME}" \
    --query 'LocationConstraint' --output text)
  if [ "$BUCKET_REGION" = "None" ]; then
    BUCKET_REGION="us-east-1"
  fi
  if [ "$BUCKET_REGION" != "$AWS_REGION" ]; then
    echo "Error: existing bucket is in $BUCKET_REGION, expected $AWS_REGION." >&2
    exit 1
  fi
else
  echo "Creating S3 bucket ${BUCKET_NAME}..."
  if [ "${AWS_REGION}" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${AWS_REGION}"
  else
    aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${AWS_REGION}" \
      --create-bucket-configuration LocationConstraint="${AWS_REGION}"
  fi
fi

# Converge security controls even when reusing a remnant backend bucket.
aws s3api put-bucket-versioning --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
  'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'

echo "==> Backend bootstrap completed successfully!"
