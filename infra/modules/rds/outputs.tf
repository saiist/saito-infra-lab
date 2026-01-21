output "db_endpoint" { value = aws_db_instance.this.address }
output "db_port" { value = aws_db_instance.this.port }

output "secret_arn" { value = aws_secretsmanager_secret.db.arn }
output "db_name" { value = var.db_name }
output "db_username" { value = var.db_username }
