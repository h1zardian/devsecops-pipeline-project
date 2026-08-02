output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster control plane endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "rds_endpoint" {
  description = "RDS database endpoint"
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "github_oidc_role_arn" {
  description = "GitHub Actions AWS OIDC IAM Role ARN"
  value       = module.oidc.github_oidc_role_arn
}

output "github_plan_oidc_role_arn" {
  description = "Read-only GitHub Actions AWS OIDC role ARN for Terraform plans"
  value       = module.oidc.github_plan_oidc_role_arn
}

output "eso_irsa_role_arn" {
  description = "External Secrets Operator IRSA role ARN"
  value       = module.oidc.eso_irsa_role_arn
}
