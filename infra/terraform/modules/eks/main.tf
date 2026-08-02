module "eks" {
  #checkov:skip=CKV_TF_1:Registry module is version constrained and checksummed in the root .terraform.lock.hcl.
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.24"

  name               = var.cluster_name
  kubernetes_version = "1.34"

  endpoint_public_access                   = length(var.cluster_endpoint_public_access_cidrs) > 0
  endpoint_public_access_cidrs             = var.cluster_endpoint_public_access_cidrs
  endpoint_private_access                  = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # KMS envelope encryption for Secrets
  create_kms_key = true
  encryption_config = {
    resources = ["secrets"]
  }

  eks_managed_node_groups = {
    default = {
      instance_types    = ["t3.medium"]
      min_size          = 2
      max_size          = 3
      desired_size      = 2
      enable_monitoring = true

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
