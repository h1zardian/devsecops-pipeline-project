output "db_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "db_name" {
  value = aws_db_instance.postgres.db_name
}

output "kms_key_arn" {
  description = "KMS key ARN used to encrypt RDS and application secrets"
  value       = aws_kms_key.rds.arn
}
