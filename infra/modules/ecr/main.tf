resource "aws_ecr_repository" "worker" {
  name = "${var.project_name}-worker"
  force_delete = true
  tags = { Name = "${var.project_name}-worker"}
}

resource "aws_ecr_repository" "api" {
  name = "${var.project_name}-api"
  force_delete = true
  tags = { Name = "${var.project_name}-api"}
}