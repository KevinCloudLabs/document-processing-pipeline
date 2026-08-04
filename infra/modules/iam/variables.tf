variable "project_name" {
  type    = string
  default = "dpp"
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider_url" {
  description = "EKS cluster OIDC issuer URL, without the https:// prefix"
  type        = string
}

variable "sqs_queue_arn" {
  type = string
}

variable "s3_bucket_arn" {
  type = string
}
