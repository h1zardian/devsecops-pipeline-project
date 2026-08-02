#!/usr/bin/env bash
# Cleanup script to safely tear down Kubernetes-created AWS load balancers and
# their dedicated security groups before running terraform destroy.

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

# Capture the security groups attached to load balancers before deleting the
# load balancers. Shared EKS, node, RDS, and Terraform-managed security groups
# are deliberately excluded from deletion below.
LB_SECURITY_GROUPS="$(
  aws elb describe-load-balancers --region "$REGION" \
    --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].SecurityGroups[]" \
    --output text 2>/dev/null || true
  aws elbv2 describe-load-balancers --region "$REGION" \
    --query "LoadBalancers[?VpcId=='$VPC_ID'].SecurityGroups[]" \
    --output text 2>/dev/null || true
)"

# 1. Delete Classic Load Balancers
echo "==> Checking Classic Load Balancers (ELB)..."
for elb in $(aws elb describe-load-balancers --region "$REGION" \
  --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" --output text 2>/dev/null); do
  if [ -n "$elb" ] && [ "$elb" != "None" ]; then
    echo "Deleting Classic ELB: $elb"
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

# 3. Delete only dedicated Kubernetes load-balancer security groups. Never
# sweep all VPC security groups: most of them are owned by Terraform.
echo "==> Cleaning up dedicated Kubernetes load-balancer security groups..."
for sg in $LB_SECURITY_GROUPS; do
  if [ -z "$sg" ] || [ "$sg" = "None" ]; then
    continue
  fi

  SG_DETAILS=$(aws ec2 describe-security-groups --region "$REGION" \
    --group-ids "$sg" --query 'SecurityGroups[0].[GroupName,Description]' \
    --output text 2>/dev/null || true)
  SG_NAME=${SG_DETAILS%%$'\t'*}
  SG_DESCRIPTION=${SG_DETAILS#*$'\t'}
  SG_OWNER_TAGS=$(aws ec2 describe-security-groups --region "$REGION" \
    --group-ids "$sg" \
    --query "length(SecurityGroups[0].Tags[?Key=='kubernetes.io/service-name' || Key=='elbv2.k8s.aws/resource'])" \
    --output text 2>/dev/null || echo 0)

  if [[ "$SG_NAME" == k8s-* || "$SG_NAME" == k8s_* || \
    "$SG_DESCRIPTION" == *"Kubernetes ELB"* || "$SG_OWNER_TAGS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Deleting Kubernetes load-balancer Security Group: $sg"
    for attempt in 1 2 3 4 5 6; do
      if aws ec2 delete-security-group --group-id "$sg" --region "$REGION" 2>/dev/null; then
        break
      fi
      if [ "$attempt" -eq 6 ]; then
        echo "==> Warning: $sg is still in use; Terraform will retry during destroy."
        break
      fi
      sleep 5
    done
  else
    echo "Leaving shared or Terraform-managed Security Group unchanged: $sg ($SG_NAME)"
  fi
done

echo "==> Pre-destroy cleanup completed successfully."
