terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "networking" {
  source = "./modules/networking"

  aws_region   = var.aws_region
  project_name = var.project_name
}

module "storage" {
  source = "./modules/storage"

  project_name = var.project_name
}

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
}

module "database" {
  source = "./modules/database"

  project_name       = var.project_name
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  db_password        = var.db_password
}

module "eks" {
  source = "./modules/eks"

  project_name       = var.project_name
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
}

module "iam" {
  source = "./modules/iam"

  project_name       = var.project_name
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  sqs_queue_arn      = module.storage.sqs_queue_arn
  s3_bucket_arn      = module.storage.s3_bucket_arn
}

module "cicd" {
  source = "./modules/cicd"

  project_name          = var.project_name
  github_repo           = var.github_repo
  github_branch         = var.github_branch
  cluster_name          = module.eks.cluster_name
  cluster_arn           = module.eks.cluster_arn
  worker_repository_arn = module.ecr.worker_repository_arn
  api_repository_arn    = module.ecr.api_repository_arn
}
