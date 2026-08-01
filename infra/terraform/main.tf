provider "aws" {
  region = var.aws_region
}

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
  region                               = var.aws_region
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
  source      = "./modules/oidc"
  github_repo = var.github_repo
  environment = var.environment
}
