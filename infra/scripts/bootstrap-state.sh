#!/usr/bin/env bash
set -euo pipefail

# Script to bootstrap S3 Bucket for Terraform Remote State.
# Note: DynamoDB locking has been replaced by S3-native locking (use_lockfile = true)
# which requires no additional infrastructure.
AWS_REGION="${AWS_REGION:-ap-south-1}"
BUCKET_NAME="${TF_STATE_BUCKET:-devsecops-tf-state-backend-072329308666}"

echo "==> Bootstrapping Terraform Remote State Backend"
echo "Region: ${AWS_REGION}"
echo "S3 Bucket: ${BUCKET_NAME}"

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

echo "==> Backend bootstrap completed successfully!"
