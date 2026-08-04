variable "project_name" {
  type    = string
  default = "dpp"
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the deploy role, as owner/name (e.g. kevin/aws-document-processing-pipeline)"
  type        = string
}

variable "github_branch" {
  description = "Branch allowed to assume the deploy role. Scoping to a single branch prevents a PR from a fork from deploying."
  type        = string
  default     = "main"
}

variable "cluster_name" {
  type = string
}

variable "cluster_arn" {
  type = string
}

variable "worker_repository_arn" {
  type = string
}

variable "api_repository_arn" {
  type = string
}
