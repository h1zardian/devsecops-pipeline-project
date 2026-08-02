variable "github_repo" {
  description = "GitHub repository owner/repo string for OIDC subject condition"
  type        = string
}

variable "environment" {
  description = "Environment tag"
  type        = string
}

variable "eks_oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider for IRSA role"
  type        = string
  default     = ""
}

variable "eks_oidc_issuer_url" {
  description = "Issuer URL of the EKS OIDC provider for IRSA role"
  type        = string
  default     = ""
}
