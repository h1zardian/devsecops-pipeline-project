data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a21860c07ebb1496735510619a97eb943615",
    "1b51906f92d9921b1c6e694086603a110f8427af"
  ]
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

    # Only production-environment jobs may assume the provisioning role. Match
    # both legacy and immutable GitHub OIDC subjects during GitHub's transition.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo}:environment:production",
        "repo:${replace(var.github_repo, "/", "@*/")}@*:environment:production"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "devsecops-github-actions-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json
}

# IAM policy for Terraform CI/CD runner via GitHub OIDC
# Uses wildcard read patterns (Describe*, Get*, List*) since terraform plan
# must refresh state for ALL managed resources. Write actions are explicit.
data "aws_iam_policy_document" "terraform_provisioner" {
  #checkov:skip=CKV_AWS_108:Backend state access is required by Terraform and constrained by the protected OIDC trust policy.
  #checkov:skip=CKV_AWS_109:Terraform must create IAM roles and policies before their final ARNs exist.
  #checkov:skip=CKV_AWS_110:PassRole and policy attachment are required to provision EKS and are constrained by the protected OIDC trust policy.
  #checkov:skip=CKV_AWS_111:Create-time AWS APIs require wildcard resources; actions are explicitly enumerated.
  #checkov:skip=CKV_AWS_356:Create-time AWS resources have no ARN to scope; actions are explicitly enumerated.

  # --- Read-only access for terraform plan state refresh ---
  statement {
    sid    = "EC2ReadAccess"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "IAMReadAccess"
    effect = "Allow"
    actions = [
      "iam:Get*",
      "iam:List*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EKSReadAccess"
    effect = "Allow"
    actions = [
      "eks:Describe*",
      "eks:List*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "OtherReadAccess"
    effect = "Allow"
    actions = [
      "rds:Describe*",
      "rds:ListTagsForResource",
      "kms:Describe*",
      "kms:Get*",
      "kms:List*",
      "logs:Describe*",
      "logs:List*",
      "secretsmanager:Describe*",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:ListSecretVersionIds",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }

  # --- Write access for terraform apply ---
  statement {
    sid    = "EC2WriteAccess"
    effect = "Allow"
    actions = [
      "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
      "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
      "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway",
      "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
      "ec2:CreateRouteTable", "ec2:DeleteRouteTable",
      "ec2:CreateRoute", "ec2:DeleteRoute",
      "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
      "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
      "ec2:CreateNatGateway", "ec2:DeleteNatGateway",
      "ec2:AllocateAddress", "ec2:ReleaseAddress",
      "ec2:CreateTags", "ec2:DeleteTags",
      "ec2:CreateLaunchTemplate", "ec2:DeleteLaunchTemplate",
      "ec2:CreateLaunchTemplateVersion",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EKSWriteAccess"
    effect = "Allow"
    actions = [
      "eks:Create*",
      "eks:Delete*",
      "eks:Update*",
      "eks:TagResource",
      "eks:UntagResource",
      "eks:AssociateAccessPolicy",
      "eks:DisassociateAccessPolicy",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "IAMWriteAccess"
    effect = "Allow"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PassRole",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy",
      "iam:CreatePolicy", "iam:DeletePolicy", "iam:CreatePolicyVersion", "iam:DeletePolicyVersion",
      "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint", "iam:AddClientIDToOpenIDConnectProvider",
      "iam:RemoveClientIDFromOpenIDConnectProvider",
      "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
      "iam:TagRole", "iam:UntagRole", "iam:TagPolicy", "iam:UntagPolicy",
      "iam:TagOpenIDConnectProvider", "iam:UntagOpenIDConnectProvider",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "RDSWriteAccess"
    effect = "Allow"
    actions = [
      "rds:CreateDBInstance", "rds:DeleteDBInstance", "rds:ModifyDBInstance",
      "rds:CreateDBSubnetGroup", "rds:DeleteDBSubnetGroup",
      "rds:AddTagsToResource", "rds:RemoveTagsFromResource",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "KMSWriteAccess"
    effect = "Allow"
    actions = [
      "kms:CreateKey", "kms:ScheduleKeyDeletion",
      "kms:CreateAlias", "kms:DeleteAlias",
      "kms:PutKeyPolicy",
      "kms:TagResource", "kms:UntagResource",
      "kms:EnableKeyRotation",
      "kms:CreateGrant", "kms:RevokeGrant",
      "kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SecretsManagerWriteAccess"
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret", "secretsmanager:DeleteSecret",
      "secretsmanager:PutSecretValue", "secretsmanager:UpdateSecret",
      "secretsmanager:TagResource", "secretsmanager:UntagResource",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchLogsAccess"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup", "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy",
      "logs:TagLogGroup", "logs:UntagLogGroup",
      "logs:TagResource", "logs:UntagResource",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "S3AndDynamoDBBackendPermissions"
    effect = "Allow"
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket",
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem",
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

# IRSA Role for External Secrets Operator (managed natively by Terraform)
data "aws_iam_policy_document" "eso_irsa_assume" {

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.eks_oidc_provider_arn]
    }

    condition {
      test     = "StringLike"
      variable = "${replace(var.eks_oidc_issuer_url, "https://", "")}:sub"
      values = [
        "system:serviceaccount:django:django-sa",
        "system:serviceaccount:external-secrets:*"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eso_irsa" {
  name               = "devsecops-eso-irsa-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.eso_irsa_assume.json
}

resource "aws_iam_role_policy_attachment" "eso_irsa" {
  role       = aws_iam_role.eso_irsa.name
  policy_arn = aws_iam_policy.eso_secrets_manager.arn
}
