output "github_oidc_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "github_plan_oidc_role_arn" {
  value = aws_iam_role.github_actions_plan.arn
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "eso_policy_arn" {
  value = aws_iam_policy.eso_secrets_manager.arn
}

output "eso_irsa_role_arn" {
  description = "IAM role assumed only by the External Secrets service account"
  value       = aws_iam_role.eso_irsa.arn
}
