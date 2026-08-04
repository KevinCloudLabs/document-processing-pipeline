terraform {
  backend "s3" {
    bucket       = "kevin-terraform-state"
    key          = "document-pipeline/terraform.tfstate"
    region       = "us-west-1"
    use_lockfile = true
  }
}
