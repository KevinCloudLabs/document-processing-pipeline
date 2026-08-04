output "rds_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "db_security_group_id" {
  value = aws_security_group.db.id
}