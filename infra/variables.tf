variable "aws_region" {
  type    = string
  default = "us-west-1"
}

variable "project_name" {
  type    = string
  default = "dpp"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the CI/CD deploy role, as owner/name"
  type        = string
}

variable "github_branch" {
  type    = string
  default = "main"
}
