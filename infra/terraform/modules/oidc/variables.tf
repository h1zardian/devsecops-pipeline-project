variable "github_repo" {
  description = "GitHub repository owner/repo string for OIDC subject condition"
  type        = string
}

variable "github_oidc_provider_arn" {
  description = "Existing account-level GitHub Actions OIDC provider ARN; null creates and owns one"
  type        = string
  default     = null

  validation {
    condition     = var.github_oidc_provider_arn == null || can(regex("^arn:aws:iam::[0-9]{12}:oidc-provider/token\\.actions\\.githubusercontent\\.com$", var.github_oidc_provider_arn))
    error_message = "github_oidc_provider_arn must be null or the account's token.actions.githubusercontent.com provider ARN."
  }
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
