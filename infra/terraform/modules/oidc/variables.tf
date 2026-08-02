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

variable "secrets_kms_key_arn" {
  description = "KMS key ARN used by Secrets Manager for application secrets"
  type        = string
}

variable "terraform_state_bucket" {
  description = "S3 bucket containing the Terraform backend state"
  type        = string
}

variable "terraform_state_key" {
  description = "S3 object key containing the Terraform backend state"
  type        = string
}
