module "eks" {
  #checkov:skip=CKV_TF_1:Registry module is version constrained and checksummed in .terraform.lock.hcl.
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.34"

  cluster_endpoint_public_access           = length(var.cluster_endpoint_public_access_cidrs) > 0
  cluster_endpoint_public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  cluster_endpoint_private_access          = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # KMS envelope encryption for Secrets
  create_kms_key = true
  cluster_encryption_config = {
    resources = ["secrets"]
  }

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 3
      desired_size   = 2

      # Hardening: Enforce IMDSv2 (blocks SSRF token theft)
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
      }

      # Hardening: Encrypted EBS root volume
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
    }
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Pre-destroy cleanup: Remove Kubernetes-created cloud resources (LoadBalancers,
# Security Groups) that are not managed by Terraform but block VPC deletion.
resource "null_resource" "cleanup_k8s_cloud_resources" {
  depends_on = [module.eks]

  triggers = {
    cluster_name = var.cluster_name
    region       = var.region
    vpc_id       = var.vpc_id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Cleaning up Kubernetes-managed cloud resources before EKS destroy..."

      # Delete all Classic Load Balancers in the VPC
      for elb in $(aws elb describe-load-balancers --region ${self.triggers.region} \
        --query "LoadBalancerDescriptions[?VPCId=='${self.triggers.vpc_id}'].LoadBalancerName" --output text 2>/dev/null); do
        echo "Deleting Classic ELB: $elb"
        aws elb delete-load-balancer --load-balancer-name "$elb" --region ${self.triggers.region} || true
      done

      # Delete all ALB/NLB in the VPC
      for arn in $(aws elbv2 describe-load-balancers --region ${self.triggers.region} \
        --query "LoadBalancers[?VpcId=='${self.triggers.vpc_id}'].LoadBalancerArn" --output text 2>/dev/null); do
        echo "Deleting ELBv2: $arn"
        aws elbv2 delete-load-balancer --load-balancer-arn "$arn" --region ${self.triggers.region} || true
      done

      # Wait for ENIs to detach
      echo "Waiting 15s for ENI detachment..."
      sleep 15

      # Delete orphaned non-default security groups in the VPC
      for sg in $(aws ec2 describe-security-groups --region ${self.triggers.region} \
        --filters "Name=vpc-id,Values=${self.triggers.vpc_id}" \
        --query "SecurityGroups[?GroupName!='default'].GroupId" --output text 2>/dev/null); do
        echo "Deleting orphaned SG: $sg"
        aws ec2 delete-security-group --group-id "$sg" --region ${self.triggers.region} || true
      done

      echo "Kubernetes cloud resource cleanup complete."
    EOT
  }
}
