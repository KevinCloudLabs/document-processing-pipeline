output "s3_bucket_name" {
  value = module.storage.s3_bucket_name
}

output "sqs_queue_url" {
  value = module.storage.sqs_queue_url
}

output "rds_endpoint" {
  value = module.database.rds_endpoint
}

output "worker_repository_url" {
  value = module.ecr.worker_repository_url
}

output "api_repository_url" {
  value = module.ecr.api_repository_url
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "worker_role_arn" {
  value = module.iam.worker_role_arn
}

output "keda_operator_role_arn" {
  value = module.iam.keda_operator_role_arn
}

output "github_actions_role_arn" {
  value = module.cicd.github_actions_role_arn
}
