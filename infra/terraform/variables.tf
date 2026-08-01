variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (dev, prod)"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "devsecops-eks-cluster"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_password" {
  description = "RDS PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "GitHub repository format owner/repo for OIDC trust"
  type        = string
  default     = "h1zardian/devsecops-platform-provisioning-pipeline"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDRs allowed to access EKS API server"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

