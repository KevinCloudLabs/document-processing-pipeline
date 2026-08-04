output "github_actions_role_arn" {
  description = "Set this as the AWS_DEPLOY_ROLE secret (or hardcode it) in the GitHub workflow"
  value       = aws_iam_role.github_actions.arn
}
