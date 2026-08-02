#!/usr/bin/env bash
# Cleanup script to safely tear down Kubernetes-created AWS cloud resources
# (Classic Load Balancers, ELBv2s, and Security Groups) before running terraform destroy.

set -euo pipefail

REGION="${AWS_REGION:-ap-south-1}"
VPC_ID="${1:-}"

if [ -z "$VPC_ID" ]; then
  # Automatically discover VPC ID for dev environment if not supplied
  VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" \
    --filters "Name=tag:Name,Values=devsecops-vpc-dev" \
    --query "Vpcs[0].VpcId" --output text 2>/dev/null || true)
fi

if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ]; then
  echo "==> No active VPC found for cleanup. Continuing..."
  exit 0
fi

echo "==> Starting AWS pre-destroy cleanup for VPC: $VPC_ID in region: $REGION"

# 1. Delete Classic Load Balancers
echo "==> Checking Classic Load Balancers (ELB)..."
for elb in $(aws elb describe-load-balancers --region "$REGION" \
  --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" --output text 2>/dev/null); do
  if [ -n "$elb" ] && [ "$elb" != "None" ]; then
    echo "Deletng Classic ELB: $elb"
    aws elb delete-load-balancer --load-balancer-name "$elb" --region "$REGION" || true
  fi
done

# 2. Delete ALB / NLBs (ELBv2)
echo "==> Checking ELBv2 Load Balancers..."
for arn in $(aws elbv2 describe-load-balancers --region "$REGION" \
  --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text 2>/dev/null); do
  if [ -n "$arn" ] && [ "$arn" != "None" ]; then
    echo "Deleting ELBv2: $arn"
    aws elbv2 delete-load-balancer --load-balancer-arn "$arn" --region "$REGION" || true
  fi
done

# Wait for Network Interfaces to detach
echo "==> Waiting 10s for Network Interfaces to detach..."
sleep 10

# 3. Revoke Security Group Rules and Delete Security Groups
echo "==> Cleaning up Security Groups..."
SGS=$(aws ec2 describe-security-groups --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[?GroupName!='default'].GroupId" --output text 2>/dev/null || true)

for sg in $SGS; do
  if [ -n "$sg" ] && [ "$sg" != "None" ]; then
    echo "Revoking ingress/egress rules for Security Group: $sg"
    aws ec2 revoke-security-group-ingress --group-id "$sg" --region "$REGION" --protocol -1 --port -1 --cidr 0.0.0.0/0 2>/dev/null || true
    aws ec2 revoke-security-group-egress --group-id "$sg" --region "$REGION" --protocol -1 --port -1 --cidr 0.0.0.0/0 2>/dev/null || true
  fi
done

for sg in $SGS; do
  if [ -n "$sg" ] && [ "$sg" != "None" ]; then
    echo "Deleting Security Group: $sg"
    aws ec2 delete-security-group --group-id "$sg" --region "$REGION" 2>/dev/null || true
  fi
done

echo "==> Pre-destroy cleanup completed successfully."
