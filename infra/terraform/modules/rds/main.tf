resource "aws_db_subnet_group" "rds" {
  name       = "devsecops-db-subnet-group-${var.environment}"
  subnet_ids = var.subnet_ids

  tags = {
    Environment = var.environment
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

resource "aws_kms_key" "rds" {
  description             = "RDS and Django Secrets Manager encryption key for ${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "EnableAccountIAMPolicies"
      Effect = "Allow"
      Principal = {
        AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action   = "kms:*"
      Resource = "*"
    }]
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/devsecops-rds-${var.environment}"
  target_key_id = aws_kms_key.rds.key_id
}

data "aws_iam_policy_document" "rds_monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name               = "devsecops-rds-monitoring-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume.json
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_security_group" "rds" {
  name        = "devsecops-rds-sg-${var.environment}"
  description = "Allow PostgreSQL traffic from VPC"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

}

resource "aws_db_instance" "postgres" {
  #checkov:skip=CKV_AWS_293:Deletion protection is enabled for prod; dev is intentionally disposable.
  #checkov:skip=CKV_AWS_157:Multi-AZ is enabled for prod; dev uses a single AZ to control demonstration cost.
  #checkov:skip=CKV2_AWS_30:Full SQL statement logging can expose patient data; engine and slow-query events are exported instead.
  identifier             = "devsecops-postgres-${var.environment}"
  allocated_storage      = 20
  max_allocated_storage  = 50
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = var.environment == "prod" ? "db.t3.medium" : "db.t3.micro"
  db_name                = "hospital_db"
  username               = "postgres"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  auto_minor_version_upgrade            = true
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
  iam_database_authentication_enabled   = true
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.rds.arn
  performance_insights_retention_period = 7
  copy_tags_to_snapshot                 = true

  multi_az            = var.environment == "prod" ? true : false
  storage_encrypted   = true
  kms_key_id          = aws_kms_key.rds.arn
  skip_final_snapshot = var.environment == "prod" ? false : true
  deletion_protection = var.environment == "prod" ? true : false

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "random_password" "django_secret_key" {
  length  = 50
  special = false
}

resource "random_password" "grafana_admin_password" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "django" {
  #checkov:skip=CKV2_AWS_57:Rotation needs coordinated application credential rollover and is managed as an operational procedure.
  name                    = "${var.environment}/django"
  description             = "Django application secrets for ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 7 : 0
  kms_key_id              = aws_kms_key.rds.arn

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_secretsmanager_secret_version" "django" {
  secret_id = aws_secretsmanager_secret.django.id
  secret_string = jsonencode({
    secret_key             = random_password.django_secret_key.result
    db_password            = var.db_password
    grafana_admin_user     = "admin"
    grafana_admin_password = random_password.grafana_admin_password.result
  })
}
