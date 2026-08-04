output "worker_role_arn" {
  value = aws_iam_role.worker.arn
}

output "keda_operator_role_arn" {
  value = aws_iam_role.keda_operator.arn
}
