data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "devsecops-github-actions-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json
}

# Least-privilege IAM policy document for Terraform infrastructure provisioning
# Note: Resources are set to "*" for dynamic infrastructure creation; in strict enterprise environments,
# scope resources to specific ARNs (e.g. arn:aws:eks:us-east-1:123456789012:cluster/devsecops-*).
data "aws_iam_policy_document" "terraform_provisioner" {
  statement {
    sid    = "VPCAndNetworkingPermissions"
    effect = "Allow"
    actions = [
      "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:DescribeVpcs", "ec2:ModifyVpcAttribute",
      "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:DescribeSubnets", "ec2:ModifySubnetAttribute",
      "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway", "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
      "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:CreateRoute", "ec2:DeleteRoute",
      "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable", "ec2:DescribeRouteTables",
      "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
      "ec2:DescribeSecurityGroups", "ec2:CreateNatGateway", "ec2:DeleteNatGateway", "ec2:DescribeNatGateways",
      "ec2:AllocateAddress", "ec2:ReleaseAddress", "ec2:DescribeAddresses"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EKSPermissions"
    effect = "Allow"
    actions = [
      "eks:*",
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:ListRoles",
      "iam:PassRole", "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy", "iam:ListPolicyVersions",
      "kms:CreateKey", "kms:DescribeKey", "kms:CreateAlias", "kms:DeleteAlias",
      "kms:GetKeyPolicy", "kms:PutKeyPolicy"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "RDSPermissions"
    effect = "Allow"
    actions = [
      "rds:CreateDBInstance", "rds:DeleteDBInstance", "rds:DescribeDBInstances", "rds:ModifyDBInstance",
      "rds:CreateDBSubnetGroup", "rds:DeleteDBSubnetGroup", "rds:DescribeDBSubnetGroups"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "S3AndDynamoDBBackendPermissions"
    effect = "Allow"
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:ListBucket",
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SecretsManagerPermissions"
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret", "secretsmanager:DeleteSecret",
      "secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue", "secretsmanager:TagResource"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "terraform_provisioner" {
  name        = "devsecops-terraform-provisioner-policy-${var.environment}"
  description = "Least-privilege policy for DevSecOps Terraform runner via OIDC"
  policy      = data.aws_iam_policy_document.terraform_provisioner.json
}

resource "aws_iam_role_policy_attachment" "terraform_provisioner" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.terraform_provisioner.arn
}

data "aws_iam_policy_document" "eso_secrets_manager" {
  statement {
    sid    = "SecretsManagerRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      "arn:aws:secretsmanager:*:*:secret:${var.environment}/*"
    ]
  }
}

resource "aws_iam_policy" "eso_secrets_manager" {
  name        = "devsecops-eso-policy-${var.environment}"
  description = "Least-privilege policy for External Secrets Operator to access Secrets Manager"
  policy      = data.aws_iam_policy_document.eso_secrets_manager.json
}

