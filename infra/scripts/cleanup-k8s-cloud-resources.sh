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

# 3. Identify only dedicated Kubernetes load-balancer security groups. Never
# sweep all VPC security groups: most of them are owned by Terraform.
K8S_LB_SECURITY_GROUPS=""
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
    K8S_LB_SECURITY_GROUPS="$K8S_LB_SECURITY_GROUPS $sg"
  else
    echo "Leaving shared or Terraform-managed Security Group unchanged: $sg ($SG_NAME)"
  fi
done

# ELB network interfaces commonly remain for several minutes after the delete
# API returns. Retry all confirmed Kubernetes groups in rounds so groups checked
# early are retried after their network interfaces finally detach.
echo "==> Cleaning up dedicated Kubernetes load-balancer security groups..."
MAX_SG_DELETE_ATTEMPTS=30
for attempt in $(seq 1 "$MAX_SG_DELETE_ATTEMPTS"); do
  REMAINING_SECURITY_GROUPS=""

  for sg in $K8S_LB_SECURITY_GROUPS; do
    if ! aws ec2 describe-security-groups --region "$REGION" --group-ids "$sg" \
      >/dev/null 2>&1; then
      continue
    fi

    if aws ec2 delete-security-group --group-id "$sg" --region "$REGION" \
      >/dev/null 2>&1; then
      echo "Deleted Kubernetes load-balancer Security Group: $sg"
    else
      REMAINING_SECURITY_GROUPS="$REMAINING_SECURITY_GROUPS $sg"
    fi
  done

  K8S_LB_SECURITY_GROUPS="$REMAINING_SECURITY_GROUPS"
  if [ -z "${K8S_LB_SECURITY_GROUPS// }" ]; then
    break
  fi

  if [ "$attempt" -eq "$MAX_SG_DELETE_ATTEMPTS" ]; then
    echo "==> Warning: Kubernetes load-balancer security groups are still in use:$K8S_LB_SECURITY_GROUPS"
    echo "==> Rerun this cleanup after the AWS load-balancer network interfaces detach."
    break
  fi

  echo "==> Waiting 10s for load-balancer network interfaces to detach (attempt $attempt/$MAX_SG_DELETE_ATTEMPTS)..."
  sleep 10
done

echo "==> Pre-destroy cleanup completed successfully."
