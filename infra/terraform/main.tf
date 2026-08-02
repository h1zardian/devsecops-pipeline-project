provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

module "vpc" {
  source       = "./modules/vpc"
  vpc_cidr     = var.vpc_cidr
  environment  = var.environment
  cluster_name = var.cluster_name
}

module "eks" {
  source                               = "./modules/eks"
  cluster_name                         = var.cluster_name
  vpc_id                               = module.vpc.vpc_id
  subnet_ids                           = module.vpc.private_subnets
  environment                          = var.environment
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
}

module "rds" {
  source      = "./modules/rds"
  vpc_id      = module.vpc.vpc_id
  vpc_cidr    = var.vpc_cidr
  subnet_ids  = module.vpc.private_subnets
  db_password = var.db_password
  environment = var.environment
}

module "oidc" {
  source                 = "./modules/oidc"
  github_repo            = var.github_repo
  environment            = var.environment
  eks_oidc_provider_arn  = module.eks.oidc_provider_arn
  eks_oidc_issuer_url    = module.eks.cluster_oidc_issuer_url
  secrets_kms_key_arn    = module.rds.kms_key_arn
  terraform_state_bucket = "devsecops-tf-state-backend-${data.aws_caller_identity.current.account_id}"
  terraform_state_key    = "platform/devsecops-eks.tfstate"
}
