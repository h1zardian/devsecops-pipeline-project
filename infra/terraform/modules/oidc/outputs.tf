output "github_oidc_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "eso_policy_arn" {
  value = aws_iam_policy.eso_secrets_manager.arn
}

