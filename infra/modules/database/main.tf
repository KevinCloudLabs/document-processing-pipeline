resource "aws_security_group" "db" {
  name = "${var.project_name}-db-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port= 5432
    to_port = 5432
    protocol = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-db-sg"}
}

resource "aws_db_subnet_group" "main" {
  name = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags = { Name = "${var.project_name}-db-subnet-group"}
}

resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-db"
  engine = "postgres"
  instance_class = "db.t3.micro"
  allocated_storage = 20
  db_name = "dpp"
  username = "postgres"
  password = var.db_password
  db_subnet_group_name = aws_db_subnet_group.main.id
  vpc_security_group_ids = [aws_security_group.db.id]
  skip_final_snapshot = true
  deletion_protection = false
}